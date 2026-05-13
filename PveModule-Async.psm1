#requires -Version 7.0

function Test-ModuleExists {
    param([string]$Name)
    if (-not (Get-Module -ListAvailable -Name $Name)) {
        Write-Verbose "Module '$Name' not found. Installing from PSGallery..."
        Install-Module -Name $Name -Scope CurrentUser -Force -ErrorAction Stop
    }
    Import-Module $Name -ErrorAction Stop
}

function Get-ClusterNextId {
    param($Ticket)
    $resp = Invoke-PveRestApi -PveTicket $Ticket -Method Get -Resource '/cluster/nextid'
    if (-not $resp.IsSuccessStatusCode) { throw "Failed to get next VMID: $($resp.ReasonPhrase)" }
    return [int]$resp.Response.data
}

function Test-PveVmNameExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$PveTicket,
        [Parameter(Mandatory)][string]$Name
    )

    $resp = Invoke-PveRestApi -PveTicket $PveTicket -Method Get `
        -Resource '/cluster/resources' -Parameters @{ type = 'vm' }

    if (-not $resp.IsSuccessStatusCode) {
        throw "Failed to list VMs: $($resp.ReasonPhrase)"
    }

    return @($resp.Response.data | Where-Object { $_.name -eq $Name }).Count -gt 0
}

function Wait-PveTask {
    param(
        [Parameter(Mandatory)][object]$Ticket,
        [Parameter(Mandatory)][string]$Node,
        [Parameter(Mandatory)][string]$UPID,
        [int]$TimeoutSeconds = 900,
        [int]$PollSeconds = 3
    )
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $statusResp = Invoke-PveRestApi -PveTicket $Ticket -Method Get -Resource "/nodes/$Node/tasks/$UPID/status"
        if (-not $statusResp.IsSuccessStatusCode) { throw "Failed to query task status: $($statusResp.ReasonPhrase)" }
        $data = $statusResp.Response.data
        if ($null -ne $data -and $data.status -eq 'stopped') {
            if ($data.exitstatus -eq 'OK') { return }
            throw "Task failed: exitstatus=$($data.exitstatus)"
        }
        Start-Sleep -Seconds $PollSeconds
    } while ((Get-Date) -lt $deadline)
    throw "Timeout waiting for task $UPID"
}

function New-PveVmFromTemplate {
<#!
.SYNOPSIS
 Clone a Proxmox VM from a template using Corsinvest.ProxmoxVE.Api.
 Names the VM as "<UserName>-<TemplateName>", sets NIC VLANs, and (optionally) grants PVEVMUser ACL.
.DESCRIPTION
 Supports asynchronous completion via ThreadJob/Job/NoWait so you can kick off multiple clones in parallel.
#>
    [CmdletBinding(DefaultParameterSetName='ByName')]
    param(
      # Proxmox host or host:port (port defaults to 8006)
      [Parameter(Mandatory)][string]$PveHost,
      # Target Proxmox node to host the cloned VM
      [string]$TargetNode,
      # The user's name to prefix the VM with
      [Parameter(Mandatory)][ValidatePattern('^[\w\.-]+$')][string]$UserName,
      # VLAN tag (typical range 1..4094)
      [Parameter(Mandatory)][ValidateRange(1,4094)][int]$VlanTag,
      # How many NICs to configure (update existing or add new)
      [int]$NicCount = 1,
      # Template selection (one of the two)
      [Parameter(Mandatory, ParameterSetName='ById')][int]$TemplateId,
      [Parameter(Mandatory, ParameterSetName='ByName')][string]$TemplateName,
      # Network bridge to attach to (default vmbr0)
      [string]$Bridge = 'vmbr0',
      # Optional: storage to place the clone's disks on (if omitted, Proxmox decides)
      [string]$Storage,
      # Optional: explicitly set a new VMID (otherwise we fetch /cluster/nextid)
      [int]$NewVmId,
      # Auth: API token OR credentials (token format: USER@REALM!TOKENID=APITOKEN)
      [Parameter(ParameterSetName='ById')][Parameter(ParameterSetName='ByName')][string]$ApiToken,
      [Parameter(ParameterSetName='ById')][Parameter(ParameterSetName='ByName')][pscredential]$Credential,
      # ACL options
      [string]$AclUserId,
      [string]$AclRealm = 'tdm.local',
      [bool]$AclPropagate = $true,
      # Skip TLS certificate validation (lab usage)
      [switch]$SkipCertificateCheck,
      # --- Async behavior ---
      [ValidateSet('Sync','ThreadJob','Job','NoWait')][string]$Completion = 'ThreadJob',
      [int]$TaskTimeoutSeconds = 1800,
      [string]$LogPath, 

        
      # When the computed VM name already exists:
      #  Append = keep your current "append -1/-2/..." behavior 
      #  Skip   = skip just this clone (job returns a 'Skipped' result) (default)
      #  Error  = fail the job with an explicit error
      [ValidateSet('Append','Skip','Error')]
      [string]$NameExistsAction = 'Skip'

    )

    Test-ModuleExists -Name 'Corsinvest.ProxmoxVE.Api'

    # Connect to Proxmox cluster (API token OR credential)
    $hostsAndPorts = $PveHost
    try {
        if ($ApiToken) {
            $PveTicket = Connect-PveCluster -HostsAndPorts $hostsAndPorts -ApiToken $ApiToken -SkipCertificateCheck:$SkipCertificateCheck
        } else {
            if (-not $Credential) { $Credential = Get-Credential -Message "Enter Proxmox credentials (format user@realm)." }
            $PveTicket = Connect-PveCluster -HostsAndPorts $hostsAndPorts -Credentials $Credential -SkipCertificateCheck:$SkipCertificateCheck
        }
    } catch {
        throw "Connection failed: $($_.Exception.Message)"
    }

    # Find the template (from id or name) via /cluster/resources?type=vm
    $vmListResp = Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource '/cluster/resources' -Parameters @{ type = 'vm' }
    if (-not $vmListResp.IsSuccessStatusCode) { throw "Failed to list VMs: $($vmListResp.ReasonPhrase)" }
    $vmList = @($vmListResp.Response.data)

    if ($PSCmdlet.ParameterSetName -eq 'ById') {
        $template = $vmList | Where-Object { $_.vmid -eq $TemplateId }
    } else {
        $template = $vmList | Where-Object { $_.name -eq $TemplateName }
    }
    if (-not $template) { throw "Template not found." }
    if ($template.template -ne 1) { throw "Specified VM '$($template.name)' (ID $($template.vmid)) is not a template." }
    $sourceNode   = $template.node
    $templateId   = [int]$template.vmid
    $templateName = $template.name

    # Determine target node and next VMID
    if (-not $TargetNode) { $TargetNode = $sourceNode }
    if (-not $NewVmId)   { $NewVmId   = Get-ClusterNextId -Ticket $PveTicket }

    # Compose new VM name: "<UserName>-<TemplateName>", sanitize for Proxmox (A-Za-z0-9_.- only)
    $newNameRaw = "$UserName-$templateName"
    $newName    = ($newNameRaw -replace '[^A-Za-z0-9_.-]','-')

    # Ensure uniqueness (append -1, -2, ... if needed)
    # Check if name exists
    $nameCollision = $vmList | Where-Object { $_.name -eq $newName }

    if ($nameCollision) {
        switch ($NameExistsAction) {
            'Skip' {
                Write-Host "VM name '$newName' already exists. Skipping this clone..."
                $result = [pscustomobject]@{
                    Name    = $newName
                    VMID    = $null
                    Node    = $TargetNode
                    Result  = 'Skipped-NameExists'
                }

                return Start-Job -ScriptBlock { param($r) $r } -ArgumentList $result
            }
            'Error' {
                throw "VM name '$newName' already exists. Aborting as per NameExistsAction=Error."
            }
            'Append' {
                # Append -1, -2, ... until unique
                $i = 1
                while ($vmList | Where-Object { $_.name -eq $newName }) {
                    $candidate = "$newNameRaw-$i" -replace '[^A-Za-z0-9_.-]', '-'
                    if (-not ($vmList | Where-Object { $_.name -eq $candidate })) {
                        $newName = $candidate
                        break
                    }
                    $i++
                }
            }
        }
    }

    Write-Host "Cloning template '$templateName' (ID $templateId on $sourceNode) -> New VMID $NewVmId named '$newName' on node '$TargetNode'..."

    # Clone the VM (full clone by default). Optional storage override.
    $cloneParams = @{ newid = $NewVmId; name = $newName; target = $TargetNode; full = 0 }
    if ($Storage) { $cloneParams['storage'] = $Storage }
    $cloneResp = Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$sourceNode/qemu/$templateId/clone" -Parameters $cloneParams
    if (-not $cloneResp.IsSuccessStatusCode) { throw "Clone failed: $($cloneResp.ReasonPhrase)" }
    $upid = $cloneResp.Response.data
    Write-Verbose "Clone task UPID: $upid"

    switch ($Completion) {
      'NoWait' {
        return [pscustomobject]@{
          Name    = $newName
          VMID    = $NewVmId
          Node    = $TargetNode
          UPID    = $upid
          Started = (Get-Date)
          Mode    = 'NoWait'
          Hint    = "Poll /nodes/$TargetNode/tasks/$upid/status to track."
        }
      }

      'Job' {
        $args = @(
          $PveHost,$TargetNode,$UserName,$VlanTag,$TemplateId,$TemplateName,
          $Bridge,$Storage,$NewVmId,$ApiToken,$Credential,$SkipCertificateCheck,
          $NicCount,$AclUserId,$AclRealm,$AclPropagate,$TaskTimeoutSeconds,$upid,$LogPath
        )
        $job = Start-Job -Name "NewPveVm-$NewVmId" -ArgumentList $args -ScriptBlock {
          param(
            $PveHost,$TargetNode,$UserName,$VlanTag,$TemplateId,$TemplateName,
            $Bridge,$Storage,$NewVmId,$ApiToken,$Credential,$SkipCertificateCheck,
            $NicCount,$AclUserId,$AclRealm,$AclPropagate,$TaskTimeoutSeconds,$upid,$LogPath
          )
          Import-Module Corsinvest.ProxmoxVE.Api -ErrorAction Stop
          function Wait-PveTask {
              param(
                  [Parameter(Mandatory)][object]$Ticket,
                  [Parameter(Mandatory)][string]$Node,
                  [Parameter(Mandatory)][string]$UPID,
                  [int]$TimeoutSeconds = 900,
                  [int]$PollSeconds = 3
              )
              $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
              do {
                  $statusResp = Invoke-PveRestApi -PveTicket $Ticket -Method Get -Resource "/nodes/$Node/tasks/$UPID/status"
                  if (-not $statusResp.IsSuccessStatusCode) { throw "Failed to query task status: $($statusResp.ReasonPhrase)" }
                  $data = $statusResp.Response.data
                  if ($null -ne $data -and $data.status -eq 'stopped') {
                      if ($data.exitstatus -eq 'OK') { return }
                      throw "Task failed: exitstatus=$($data.exitstatus)"
                  }
                  Start-Sleep -Seconds $PollSeconds
              } while ((Get-Date) -lt $deadline)
              throw "Timeout waiting for task $UPID"
          }
          if ($ApiToken) { $PveTicket = Connect-PveCluster -HostsAndPorts $PveHost -ApiToken $ApiToken -SkipCertificateCheck:$SkipCertificateCheck }
          else { $PveTicket = Connect-PveCluster -HostsAndPorts $PveHost -Credentials $Credential -SkipCertificateCheck:$SkipCertificateCheck }
          Wait-PveTask -Ticket $PveTicket -Node $TargetNode -UPID $upid -TimeoutSeconds $TaskTimeoutSeconds

          $vmConfigResp = Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$TargetNode/qemu/$NewVmId/config"
          if (-not $vmConfigResp.IsSuccessStatusCode) { throw "Failed to get VM config: $($vmConfigResp.ReasonPhrase)" }
          $vmConfig = $vmConfigResp.Response.data

          $baseVlan      = $VlanTag
          $defaultModel  = 'virtio'
          $defaultBridge = $Bridge
          $nicParams = @{}
          for ($i = 0; $i -lt $NicCount; $i++) {
            $nicName = "net$($i)"
            $vlan    = $baseVlan + $i
            if ($vlan -lt 1 -or $vlan -gt 4094) { throw "Invalid VLAN tag $vlan for $nicName (must be 1..4094)." }
            if ($vmConfig.$nicName) {
              $originalNic = $vmConfig.$nicName
              $newNic = ($originalNic -match 'tag=\d+') ? ($originalNic -replace 'tag=\d+', "tag=$vlan") : "$originalNic,tag=$vlan"
            } else {
              $newNic = "$defaultModel,bridge=$defaultBridge,tag=$vlan"
            }
            $nicParams[$nicName] = $newNic
          }
          $cfgResp = Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/nodes/$TargetNode/qemu/$NewVmId/config" -Parameters $nicParams
          if (-not $cfgResp.IsSuccessStatusCode) { throw "Failed to set NIC configs: $($cfgResp.ReasonPhrase)" }

          if (-not $AclUserId -and $UserName -and $AclRealm) { $AclUserId = "$UserName@$AclRealm" }
          if ($AclUserId) {
            $aclParams = @{ path="/vms/$NewVmId"; users=$AclUserId; roles='PVEVMUser'; propagate=([int]$AclPropagate) }
            $aclResp = Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource '/access/acl' -Parameters $aclParams
            if (-not $aclResp.IsSuccessStatusCode) { throw "Failed to set ACL: $($aclResp.ReasonPhrase)" }
          }

          $result = [pscustomobject]@{
            Name    = "$UserName-$TemplateName"
            VMID    = $NewVmId
            Node    = $TargetNode
            UPID    = $upid
            Result  = 'OK'
            NICs    = $nicParams
            ACLUser = $AclUserId
          }
          if ($LogPath) {
            $line = ('[{0}] {1} VMID={2} Node={3} UPID={4} ACL={5}' -f (Get-Date), $result.Name, $result.VMID, $result.Node, $result.UPID, $result.ACLUser)
            Add-Content -Path $LogPath -Value $line
          }
          $result
        }
        return $job
      }

      'ThreadJob' {
        $args = @(
          $PveHost,$TargetNode,$UserName,$VlanTag,$TemplateId,$TemplateName,
          $Bridge,$Storage,$NewVmId,$ApiToken,$Credential,$SkipCertificateCheck,
          $NicCount,$AclUserId,$AclRealm,$AclPropagate,$TaskTimeoutSeconds,$upid,$LogPath
        )
        $job = Start-ThreadJob -Name "NewPveVm-$NewVmId" -ArgumentList $args -ScriptBlock {
          param(
            $PveHost,$TargetNode,$UserName,$VlanTag,$TemplateId,$TemplateName,
            $Bridge,$Storage,$NewVmId,$ApiToken,$Credential,$SkipCertificateCheck,
            $NicCount,$AclUserId,$AclRealm,$AclPropagate,$TaskTimeoutSeconds,$upid,$LogPath
          )
          Import-Module Corsinvest.ProxmoxVE.Api -ErrorAction Stop
          function Wait-PveTask {
              param(
                  [Parameter(Mandatory)][object]$Ticket,
                  [Parameter(Mandatory)][string]$Node,
                  [Parameter(Mandatory)][string]$UPID,
                  [int]$TimeoutSeconds = 900,
                  [int]$PollSeconds = 3
              )
              $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
              do {
                  $statusResp = Invoke-PveRestApi -PveTicket $Ticket -Method Get -Resource "/nodes/$Node/tasks/$UPID/status"
                  if (-not $statusResp.IsSuccessStatusCode) { throw "Failed to query task status: $($statusResp.ReasonPhrase)" }
                  $data = $statusResp.Response.data
                  if ($null -ne $data -and $data.status -eq 'stopped') {
                      if ($data.exitstatus -eq 'OK') { return }
                      throw "Task failed: exitstatus=$($data.exitstatus)"
                  }
                  Start-Sleep -Seconds $PollSeconds
              } while ((Get-Date) -lt $deadline)
              throw "Timeout waiting for task $UPID"
          }
          if ($ApiToken) { $PveTicket = Connect-PveCluster -HostsAndPorts $PveHost -ApiToken $ApiToken -SkipCertificateCheck:$SkipCertificateCheck }
          else { $PveTicket = Connect-PveCluster -HostsAndPorts $PveHost -Credentials $Credential -SkipCertificateCheck:$SkipCertificateCheck }
          Wait-PveTask -Ticket $PveTicket -Node $TargetNode -UPID $upid -TimeoutSeconds $TaskTimeoutSeconds

          $vmConfigResp = Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$TargetNode/qemu/$NewVmId/config"
          if (-not $vmConfigResp.IsSuccessStatusCode) { throw "Failed to get VM config: $($vmConfigResp.ReasonPhrase)" }
          $vmConfig = $vmConfigResp.Response.data

          $baseVlan      = $VlanTag
          $defaultModel  = 'virtio'
          $defaultBridge = $Bridge
          $nicParams = @{}
          for ($i = 0; $i -lt $NicCount; $i++) {
            $nicName = "net$($i)"
            $vlan    = $baseVlan + $i
            if ($vlan -lt 1 -or $vlan -gt 4094) { throw "Invalid VLAN tag $vlan for $nicName (must be 1..4094)." }
            if ($vmConfig.$nicName) {
              $originalNic = $vmConfig.$nicName
              $newNic = ($originalNic -match 'tag=\d+') ? ($originalNic -replace 'tag=\d+', "tag=$vlan") : "$originalNic,tag=$vlan"
            } else {
              $newNic = "$defaultModel,bridge=$defaultBridge,tag=$vlan"
            }
            $nicParams[$nicName] = $newNic
          }
          $cfgResp = Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/nodes/$TargetNode/qemu/$NewVmId/config" -Parameters $nicParams
          if (-not $cfgResp.IsSuccessStatusCode) { throw "Failed to set NIC configs: $($cfgResp.ReasonPhrase)" }

          if (-not $AclUserId -and $UserName -and $AclRealm) { $AclUserId = "$UserName@$AclRealm" }
          if ($AclUserId) {
            $aclParams = @{ path="/vms/$NewVmId"; users=$AclUserId; roles='PVEVMUser'; propagate=([int]$AclPropagate) }
            $aclResp = Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource '/access/acl' -Parameters $aclParams
            if (-not $aclResp.IsSuccessStatusCode) { throw "Failed to set ACL: $($aclResp.ReasonPhrase)" }
          }

          $result = [pscustomobject]@{
            Name    = "$UserName-$TemplateName"
            VMID    = $NewVmId
            Node    = $TargetNode
            UPID    = $upid
            Result  = 'OK'
            NICs    = $nicParams
            ACLUser = $AclUserId
          }
          if ($LogPath) {
            $line = ('[{0}] {1} VMID={2} Node={3} UPID={4} ACL={5}' -f (Get-Date), $result.Name, $result.VMID, $result.Node, $result.UPID, $result.ACLUser)
            Add-Content -Path $LogPath -Value $line
          }
          $result
        }
        return $job
      }

      default {
        # Synchronous path (legacy behavior)
        Wait-PveTask -Ticket $PveTicket -Node $TargetNode -UPID $upid -TimeoutSeconds $TaskTimeoutSeconds

        # Get current NIC config of the new VM
        $vmConfigResp = Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource "/nodes/$TargetNode/qemu/$NewVmId/config"
        if (-not $vmConfigResp.IsSuccessStatusCode) { throw "Failed to get VM config: $($vmConfigResp.ReasonPhrase)" }
        $vmConfig = $vmConfigResp.Response.data

        $baseVlan      = $VlanTag
        $defaultModel  = 'virtio'
        $defaultBridge = $Bridge
        $nicParams = @{}
        for ($i = 0; $i -lt $NicCount; $i++) {
          $nicName = "net$($i)"
          $vlan    = $baseVlan + $i
          if ($vlan -lt 1 -or $vlan -gt 4094) { throw "Invalid VLAN tag $vlan for $nicName (must be 1..4094)." }
          if ($vmConfig.$nicName) {
            $originalNic = $vmConfig.$nicName
            $newNic = ($originalNic -match 'tag=\d+') ? ($originalNic -replace 'tag=\d+', "tag=$vlan") : "$originalNic,tag=$vlan"
          } else {
            $newNic = "$defaultModel,bridge=$defaultBridge,tag=$vlan"
          }
          $nicParams[$nicName] = $newNic
        }
        $cfgResp = Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource "/nodes/$TargetNode/qemu/$NewVmId/config" -Parameters $nicParams
        if (-not $cfgResp.IsSuccessStatusCode) { throw "Failed to set NIC configs: $($cfgResp.ReasonPhrase)" }

        if (-not $AclUserId -and $UserName -and $AclRealm) { $AclUserId = "$UserName@$AclRealm" }
        if ($AclUserId) {
          $aclParams = @{ path="/vms/$NewVmId"; users=$AclUserId; roles='PVEVMUser'; propagate=([int]$AclPropagate) }
          $aclResp = Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource '/access/acl' -Parameters $aclParams
          if (-not $aclResp.IsSuccessStatusCode) { throw "Failed to set ACL: $($aclResp.ReasonPhrase)" }
        }

        Write-Host ""
        Write-Host "✅ VM created successfully!"
        Write-Host "    Name     : $newName"
        Write-Host "    VMID     : $NewVmId"
        Write-Host "    Node     : $TargetNode"
        if ($AclUserId) { Write-Host "    Role 'PVEVMUser' Added to : $AclUserId" }
        Write-Host "    NICs configured:"
        $nicParams.GetEnumerator() | Sort-Object Name | ForEach-Object {
            Write-Host ("     {0} -> {1}" -f $_.Key, $_.Value)
        }
      }
    }
}

function New-MS203VMs {
    [CmdletBinding(DefaultParameterSetName='ByName')]
    param(
        [Parameter(Mandatory)][ValidatePattern('^[\w\.-]+$')][string]$UserName,
        [Parameter(Mandatory)][ValidateRange(1,4094)][int]$VlanTag,
        [Parameter(Mandatory)][pscredential]$Credential,
        
        # Use ThreadJob by default so clones run concurrently in PS7+
        [ValidateSet('ThreadJob','Job')]
        [string]$Completion = 'ThreadJob'

    )

    $jobs = @()
    $jobs += New-PveVmFromTemplate -PveHost pvec.tdm.local -UserName $UserName -VlanTag $VlanTag -Storage data -TemplateId 103 -Credential $Credential -SkipCertificateCheck -Completion $Completion
    $jobs += New-PveVmFromTemplate -PveHost pvec.tdm.local -UserName $UserName -VlanTag $VlanTag -Storage data -TemplateId 104 -Credential $Credential -SkipCertificateCheck -Completion $Completion
    $jobs += New-PveVmFromTemplate -PveHost pvec.tdm.local -UserName $UserName -VlanTag $VlanTag -NicCount 3 -Storage data -TemplateId 102 -Credential $Credential -SkipCertificateCheck -Completion $Completion
    $jobs += New-PveVmFromTemplate -PveHost pvec.tdm.local -UserName $UserName -VlanTag $VlanTag -NicCount 3 -Storage data -TemplateId 101 -Credential $Credential -SkipCertificateCheck -Completion $Completion

    
    # Wait once until ALL complete
    Wait-Job $jobs

    # Collect results and remove jobs
    $results = $jobs | Receive-Job -AutoRemoveJob -Wait

    # Optional: summarize
    $summary = $results | Select-Object Name, VMID, Node, Result, ACLUser
    $summary | Format-Table -AutoSize

    return $results

}

function New-RBFEStg2VMs {
    [CmdletBinding(DefaultParameterSetName='ByName')]
    param(
        [Parameter(Mandatory)][ValidatePattern('^[\w\.-]+$')][string]$UserName,
        [Parameter(Mandatory)][ValidateRange(1,4094)][int]$VlanTag,
        [Parameter(Mandatory)][pscredential]$Credential,
        
        # Use ThreadJob by default so clones run concurrently in PS7+
        [ValidateSet('ThreadJob','Job')]
        [string]$Completion = 'ThreadJob'

    )

    $jobs = @()
    $jobs += New-PveVmFromTemplate -PveHost pvec.tdm.local -UserName $UserName -VlanTag $VlanTag -Storage data -TemplateId 103 -Credential $Credential -SkipCertificateCheck -Completion $Completion
    $jobs += New-PveVmFromTemplate -PveHost pvec.tdm.local -UserName $UserName -VlanTag $VlanTag -Storage data -TemplateId 104 -Credential $Credential -SkipCertificateCheck -Completion $Completion
    $jobs += New-PveVmFromTemplate -PveHost pvec.tdm.local -UserName $UserName -VlanTag $VlanTag -Storage data -TemplateId 126 -Credential $Credential -SkipCertificateCheck -Completion $Completion
    $jobs += New-PveVmFromTemplate -PveHost pvec.tdm.local -UserName $UserName -VlanTag $VlanTag -NicCount 3 -Storage data -TemplateId 102 -Credential $Credential -SkipCertificateCheck -Completion $Completion
    $jobs += New-PveVmFromTemplate -PveHost pvec.tdm.local -UserName $UserName -VlanTag $VlanTag -NicCount 3 -Storage data -TemplateId 101 -Credential $Credential -SkipCertificateCheck -Completion $Completion
    
    
    # Wait once until ALL complete
    Wait-Job $jobs

    # Collect results and remove jobs
    $results = $jobs | Receive-Job -AutoRemoveJob -Wait

    # Optional: summarize
    $summary = $results | Select-Object Name, VMID, Node, Result, ACLUser
    $summary | Format-Table -AutoSize

    return $results

}

Export-ModuleMember -Function New-MS203VMs, New-PveVmFromTemplate, Wait-PveTas, New-RBFEStg2VMs

