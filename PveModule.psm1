function New-PveVmFromTemplate {
    #requires -Version 7.0
    <#
    .SYNOPSIS
        Clone a new Proxmox VM from a template using Corsinvest.ProxmoxVE.Api.
        Names the VM as "<UserName>-<TemplateName>" and sets the NIC VLAN tag.

    .REQUIREMENTS
        PowerShell 7+ recommended.
        Module: Corsinvest.ProxmoxVE.Api

    .EXAMPLE
        # API token auth (format: USER@REALM!TOKENID=APITOKEN)
        .\New-PveVmFromTemplate.ps1 `
            -PveHost pve01.lab.local `
            -TargetNode pve01 `
            -UserName "jdoe" `
            -TemplateName "Win11-Base" `
            -VlanTag 123 `
            -Bridge "vmbr0" `
            -ApiToken "root@pam!mytokenid=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

    .EXAMPLE
        # Username/password auth (you will be prompted)
        .\New-PveVmFromTemplate.ps1 `
            -PveHost 10.0.0.10 `
            -TargetNode pve02 `
            -UserName "alice" `
            -TemplateId 9000 `
            -VlanTag 20 `
            -Storage "local-lvm"
    #>

    [CmdletBinding(DefaultParameterSetName='ByName')]
    param(
    # Proxmox host or host:port (port defaults to 8006)
    [Parameter(Mandatory)]
    [string]$PveHost,

    # Target Proxmox node to host the cloned VM
    [Parameter()]
    [string]$TargetNode,

    # The user's name to prefix the VM with
    [Parameter(Mandatory)]
    [ValidatePattern('^[\w\.-]+$')]
    [string]$UserName,

    # VLAN tag (typical range 1..4094)
    [Parameter(Mandatory)]
    [ValidateRange(1,4094)]
    [int]$VlanTag,

    [Parameter()]
    [int]$NicCount = 1,

    # Template selection (one of the two)
    [Parameter(Mandatory, ParameterSetName='ById')]
    [int]$TemplateId,

    [Parameter(Mandatory, ParameterSetName='ByName')]
    [string]$TemplateName,

    # Network bridge to attach to (default vmbr0)
    [Parameter()]
    [string]$Bridge = 'vmbr0',

    # Optional: storage to place the clone's disks on (if omitted, Proxmox decides)
    [Parameter()]
    [string]$Storage,

    # Optional: explicitly set a new VMID (otherwise we fetch /cluster/nextid)
    [Parameter()]
    [int]$NewVmId,

    # Auth: API token OR credentials (token format: USER@REALM!TOKENID=APITOKEN)
    [Parameter(ParameterSetName='ById')]
    [Parameter(ParameterSetName='ByName')]
    [string]$ApiToken,

    [Parameter(ParameterSetName='ById')]
    [Parameter(ParameterSetName='ByName')]
    [pscredential]$Credential,

    [Parameter(ParameterSetName='ById')]
    [Parameter(ParameterSetName='ByName')]
    [string]$AclUserId,

    [Parameter(ParameterSetName='ById')]
    [Parameter(ParameterSetName='ByName')]
    [string]$AclRealm = 'tdm.local',

    [Parameter(ParameterSetName='ByName')]
    [bool]$AclPropagate=$true,
    
    [Parameter()]
    [ValidateSet('Sync','ThreadJob','Job','NoWait')]
    [string]$Completion = 'ThreadJob',   # default: async via Start-ThreadJob

    [Parameter()]
    [int]$TaskTimeoutSeconds = 1800,     # pass through to Wait-PveTask


    # Skip TLS certificate validation (lab usage)
    [switch]$SkipCertificateCheck
    )

    function Ensure-Module {
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
        if (-not $resp.IsSuccessStatusCode) {
            throw "Failed to get next VMID: $($resp.ReasonPhrase)"
        }
        return [int]$resp.Response.data
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
            if (-not $statusResp.IsSuccessStatusCode) {
                throw "Failed to query task status: $($statusResp.ReasonPhrase)"
            }
            $data = $statusResp.Response.data
            if ($null -ne $data -and $data.status -eq 'stopped') {
                if ($data.exitstatus -eq 'OK') { return }
                throw "Task failed: exitstatus=$($data.exitstatus)"
            }
            Start-Sleep -Seconds $PollSeconds
        } while ((Get-Date) -lt $deadline)
        throw "Timeout waiting for task $UPID"
    }

    # 1) Ensure module present and import
    Ensure-Module -Name 'Corsinvest.ProxmoxVE.Api'

    # 2) Connect to Proxmox cluster (API token OR credential)
    $hostsAndPorts = $PveHost
    try {
        if ($ApiToken) {
            $PveTicket = Connect-PveCluster -HostsAndPorts $hostsAndPorts -ApiToken $ApiToken -SkipCertificateCheck:$SkipCertificateCheck
        } else {
            if (-not $Credential) {
                $Credential = Get-Credential -Message "Enter Proxmox credentials (format user@realm)."
            }
            $PveTicket = Connect-PveCluster -HostsAndPorts $hostsAndPorts -Credentials $Credential -SkipCertificateCheck:$SkipCertificateCheck
        }
    } catch {
        throw "Connection failed: $($_.Exception.Message)"
    }

    # 3) Find the template (from id or name) via /cluster/resources?type=vm
    $vmListResp = Invoke-PveRestApi -PveTicket $PveTicket -Method Get -Resource '/cluster/resources' -Parameters @{ type = 'vm' }
    if (-not $vmListResp.IsSuccessStatusCode) {
        throw "Failed to list VMs: $($vmListResp.ReasonPhrase)"
    }
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

    # 4) Determine target node and next VMID
    if (-not $TargetNode) { $TargetNode = $sourceNode }
    if (-not $NewVmId) { $NewVmId = Get-ClusterNextId -Ticket $PveTicket }

    # 5) Compose new VM name: "<UserName>-<TemplateName>", sanitize for Proxmox (A-Za-z0-9_.- only)
    $newNameRaw = "$UserName-$templateName"
    $newName = ($newNameRaw -replace '[^A-Za-z0-9_.-]','-')
    # Ensure uniqueness (append -1, -2, ... if needed)
    $nameCollision = $vmList | Where-Object { $_.name -eq $newName }
    $i = 1
    while ($nameCollision) {
        $candidate = "$newName-$i"
        $nameCollision = $vmList | Where-Object { $_.name -eq $candidate }
        if (-not $nameCollision) { $newName = $candidate; break }
        $i++
    }

    Write-Host "Cloning template '$templateName' (ID $templateId on $sourceNode) -> New VMID $NewVmId named '$newName' on node '$TargetNode'..."

    # 6) Clone the VM (full clone by default). Optional storage override.
    $cloneParams = @{
        newid = $NewVmId
        name  = $newName
        target= $TargetNode
        full  = 1
    }
    if ($Storage) { $cloneParams['storage'] = $Storage }

    $cloneResp = Invoke-PveRestApi -PveTicket $PveTicket -Method Create -Resource "/nodes/$sourceNode/qemu/$templateId/clone" -Parameters $cloneParams
    if (-not $cloneResp.IsSuccessStatusCode) {
        throw "Clone failed: $($cloneResp.ReasonPhrase)"
    }
    $upid = $cloneResp.Response.data
    Write-Verbose "Clone task UPID: $upid"

    # 7) Wait for clone to complete
    Wait-PveTask -Ticket $PveTicket -Node $TargetNode -UPID $upid -TimeoutSeconds 1800

    # 8) Configure NIC VLAN (net0) on the cloned VM
    # How many NICs to configure (update existing or add new)

    $baseVlan = $VlanTag       # Starting VLAN tag
    $defaultModel = 'virtio'   # Default NIC model for new NICs
    $defaultBridge = $Bridge   # Default bridge for new NICs

    # Get current NIC config of the new VM
    $vmConfigResp = Invoke-PveRestApi -PveTicket $PveTicket -Method Get `
        -Resource "/nodes/$TargetNode/qemu/$NewVmId/config"

    if (-not $vmConfigResp.IsSuccessStatusCode) {
        throw "Failed to get VM config: $($vmConfigResp.ReasonPhrase)"
    }

    $vmConfig = $vmConfigResp.Response.data

    # Build NIC parameters for net0..net(N-1)
    $nicParams = @{}
    for ($i = 0; $i -lt $NicCount; $i++) {
        $nicName = "net$($i)"
        $vlan    = $baseVlan + $i

        # Validate VLAN range
        if ($vlan -lt 1 -or $vlan -gt 4094) {
            throw "Invalid VLAN tag $vlan for $nicName (must be 1..4094)."
        }

        # If NIC exists, update VLAN tag only
        if ($vmConfig.$nicName) {
            $originalNic = $vmConfig.$nicName
            if ($originalNic -match 'tag=\d+') {
                $newNic = ($originalNic -replace 'tag=\d+', "tag=$vlan")
            } else {
                $newNic = "$originalNic,tag=$vlan"
            }
        } else {
            # NIC doesn't exist, create new one
            $newNic = "$defaultModel,bridge=$defaultBridge,tag=$vlan"
        }

        $nicParams[$nicName] = $newNic
    }

    # Apply NIC changes
    $cfgResp = Invoke-PveRestApi -PveTicket $PveTicket -Method Set `
        -Resource "/nodes/$TargetNode/qemu/$NewVmId/config" `
        -Parameters $nicParams

    if (-not $cfgResp.IsSuccessStatusCode) {
        throw "Failed to set NIC configs: $($cfgResp.ReasonPhrase)"
    }




    # 9) Add PveVMUser permission to the VM


    if (-not $AclUserId -and $UserName -and $AclRealm) {
        $AclUserId = "$UserName@$AclRealm"
    }

    if ($AclUserId) {
        Write-Host "Granting role 'PVEVMUser' on /vms/$NewVmId to $AclUserId (propagate=$AclPropagate)..."
        $aclParams = @{
            path      = "/vms/$NewVmId"
            users     = $AclUserId
            roles     = 'PVEVMUser'
            propagate = ([int]$AclPropagate)
        }
        $aclResp = Invoke-PveRestApi -PveTicket $PveTicket -Method Set -Resource '/access/acl' -Parameters $aclParams
        if (-not $aclResp.IsSuccessStatusCode) {
            throw "Failed to set ACL: $($aclResp.ReasonPhrase)"
        }
    }

    Write-Host ""
    Write-Host "✅ VM created successfully!"
    Write-Host "    Name     : $newName"
    Write-Host "    VMID     : $NewVmId"
    Write-Host "    Node     : $TargetNode"
    Write-Host "    Role 'PVEVMUser' Added to : $AclUserId"
    Write-Host "NICs configured:"
    $nicParams.GetEnumerator() | Sort-Object Name | ForEach-Object {
        Write-Host (" {0} -> {1}" -f $_.Key, $_.Value)

    }
}

function New-MS203VMs {
    [CmdletBinding(DefaultParameterSetName='ByName')]
    param(
        
    [Parameter(Mandatory)]
    [ValidatePattern('^[\w\.-]+$')]
    [string]$UserName,

    # VLAN tag (typical range 1..4094)
    [Parameter(Mandatory)]
    [ValidateRange(1,4094)]
    [int]$VlanTag,

    [Parameter(Mandatory)]
    [Parameter(ParameterSetName='ById')]
    [Parameter(ParameterSetName='ByName')]
    [pscredential]$Credential
    )

    # Create a bundle of servers from 105 (WRT), 107 (W11), 108 (CS1), 110 (CS2)
    
    New-PveVmFromTemplate -PveHost pve.tdm.local -UserName $UserName -VlanTag $VlanTag -Storage StudentVMS -TemplateId 105 -Credential $Credential -SkipCertificateCheck
    New-PveVmFromTemplate -PveHost pve.tdm.local -UserName $UserName -VlanTag $VlanTag -Storage StudentVMS -TemplateId 107 -Credential $Credential -SkipCertificateCheck
    New-PveVmFromTemplate -PveHost pve.tdm.local -UserName $UserName -VlanTag $VlanTag -NicCount 3 -Storage StudentVMS -TemplateId 108 -Credential $Credential -SkipCertificateCheck
    New-PveVmFromTemplate -PveHost pve.tdm.local -UserName $UserName -VlanTag $VlanTag -NicCount 3 -Storage StudentVMS -TemplateId 110 -Credential $Credential -SkipCertificateCheck
}

Export-ModuleMember New-MS203VMs, New-PveVmFromTemplate

# SIG # Begin signature block
# MIIJdwYJKoZIhvcNAQcCoIIJaDCCCWQCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB7dMRxNIilk3Gh
# FPONh7T++SD7xXe13u76IdjR0PgsMaCCBr0wgga5MIIFoaADAgECAhNsAAARMa/Z
# whW+mfnzAAAAABExMA0GCSqGSIb3DQEBDQUAMEcxFTATBgoJkiaJk/IsZAEZFgVs
# b2NhbDETMBEGCgmSJomT8ixkARkWA3RkbTEZMBcGA1UEAxMQdGRtLUdBTEFEUklF
# TC1DQTAeFw0yNTA4MTIwODIzMDJaFw0yNjA4MTIwODIzMDJaMFIxFTATBgoJkiaJ
# k/IsZAEZFgVsb2NhbDETMBEGCgmSJomT8ixkARkWA3RkbTEPMA0GA1UECxMGQWRt
# aW5zMRMwEQYDVQQDEwpNYXJrIEFkbWluMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8A
# MIIBCgKCAQEAvJ9QpMjO7HYHA9cOidblesV+DDGlv3t/dP+w/fFl0OBQLkRJfvYh
# 2wv7ymrJYPWS7HgA4cIe1PfV1I11jgA8bFxQo4qI7rNirKEQoAVWgRBD0TuAhdSi
# cpgbZW3OtSRoOKqDidvqB0v1xyc/aloTT1CpgE805vK4Wdc2QQNEod7G+OhkEu2Q
# uhnoc0o2gevXKCCmcC2NHkB3/2x5dyAkeS/yK/ianc4g+hh8r2iMkLIBVO//3rTQ
# pVamDCnZgdNUzsrtoSrziyM1zRVdXHOt+Yxy+tOH9Zc2yFo0zmWqAItaZerHVS0o
# ZHK972yyPxbkQOkDJGrJHuYksz2B0MBawQIDAQABo4IDkTCCA40wOwYJKwYBBAGC
# NxUHBC4wLAYkKwYBBAGCNxUIiMNz2Z1ogp2RLISi6GSHyuppEIKL7hmE9bUNAgFl
# AgEFMD8GA1UdJQQ4MDYGCisGAQQBgjcKAwwGCCsGAQUFBwMDBggrBgEFBQcDAgYI
# KwYBBQUHAwQGCisGAQQBgjcKAwQwDgYDVR0PAQH/BAQDAgXgME8GCSsGAQQBgjcV
# CgRCMEAwDAYKKwYBBAGCNwoDDDAKBggrBgEFBQcDAzAKBggrBgEFBQcDAjAKBggr
# BgEFBQcDBDAMBgorBgEEAYI3CgMEMEQGCSqGSIb3DQEJDwQ3MDUwDgYIKoZIhvcN
# AwICAgCAMA4GCCqGSIb3DQMEAgIAgDAHBgUrDgMCBzAKBggqhkiG9w0DBzAdBgNV
# HQ4EFgQUkbO5ZU124BQyGjvnrxHj1eRLa60wHwYDVR0jBBgwFoAU2ocYt/vND+Pd
# mkKBpZYzAZQR+nwwgc4GA1UdHwSBxjCBwzCBwKCBvaCBuoaBt2xkYXA6Ly8vQ049
# dGRtLUdBTEFEUklFTC1DQSxDTj1nYWxhZHJpZWwsQ049Q0RQLENOPVB1YmxpYyUy
# MEtleSUyMFNlcnZpY2VzLENOPVNlcnZpY2VzLENOPUNvbmZpZ3VyYXRpb24sREM9
# dGRtLERDPWxvY2FsP2NlcnRpZmljYXRlUmV2b2NhdGlvbkxpc3Q/YmFzZT9vYmpl
# Y3RDbGFzcz1jUkxEaXN0cmlidXRpb25Qb2ludDCBwAYIKwYBBQUHAQEEgbMwgbAw
# ga0GCCsGAQUFBzAChoGgbGRhcDovLy9DTj10ZG0tR0FMQURSSUVMLUNBLENOPUFJ
# QSxDTj1QdWJsaWMlMjBLZXklMjBTZXJ2aWNlcyxDTj1TZXJ2aWNlcyxDTj1Db25m
# aWd1cmF0aW9uLERDPXRkbSxEQz1sb2NhbD9jQUNlcnRpZmljYXRlP2Jhc2U/b2Jq
# ZWN0Q2xhc3M9Y2VydGlmaWNhdGlvbkF1dGhvcml0eTBABgNVHREEOTA3oDUGCisG
# AQQBgjcUAgOgJwwlbWFyay5hZG1pbkBtYXJrb25ldGVjaG5vbG9naWVzLmNvbS5h
# dTBQBgkrBgEEAYI3GQIEQzBBoD8GCisGAQQBgjcZAgGgMQQvUy0xLTUtMjEtMTA5
# MTAxMzUwNy0xODY5NDAyNTk1LTE3MTg3NDU2NjAtMTI4OTUwDQYJKoZIhvcNAQEN
# BQADggEBAKerR5QQPJ2YPxmNG9BIWUZMeZ1jKuO/RWGEqvy69AUJsEnzwQ5RL0em
# zBPp3uepYui7Z8Hxx7FEwAYq93p35a6id+ZbsGrrILbv62Qt/E845HJtzePiMmW4
# PQo6JP85aZDf/SNeKUCAposE6FCUvmcgSohY3SgConmJnQHISMhniE0EdrLEQM+H
# s+Vkdrb+0Viw19umurDCCHSkKjY8yX6d76qW94MIMIZ30FMpYy53NYbqWap9hocg
# tERRc9Vvm53syjemHagRezeHUbo3YFs/Eld3/C2cgPfS4aDtGmb2JsJNYy3REyvZ
# SZAZ36QUI7YeiSVRkvEPLXpI1VpWUZgxggIQMIICDAIBATBeMEcxFTATBgoJkiaJ
# k/IsZAEZFgVsb2NhbDETMBEGCgmSJomT8ixkARkWA3RkbTEZMBcGA1UEAxMQdGRt
# LUdBTEFEUklFTC1DQQITbAAAETGv2cIVvpn58wAAAAARMTANBglghkgBZQMEAgEF
# AKCBhDAYBgorBgEEAYI3AgEMMQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgor
# BgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMC8GCSqGSIb3
# DQEJBDEiBCB9h1YyRJE20EsTjEegZ9pOWPQ55p/p6kOcI44tBM3VITANBgkqhkiG
# 9w0BAQEFAASCAQBwEw9dblGLH+SLvXmS5x4LU1TSGzS8kZy7d9iVT6R/UWl9jQu5
# B55fZE81ZIxOvvv7gBahSJfhW0/h6NewbPBAigFxDQuq2uL0/8FFfr/O/ZuIqboM
# ub9NU+4o8qFfTRnz3eMu9ZUxB/BN/tAny8Gw5bEaXlNNqEsc4CXuoAqucNAZzGVV
# sTMSTVYOuy6d6isJn6+COr1G6uKYKJTgiY9gFtj9MGL+FHGi5CvCv3OhCBeM6k+y
# aoOxvdVU9cg1D+5aegtpP705OX3pf5tLhXOT7AyOOSy+DR1QRSpZHOg9EEW4PdwA
# MiPMgdmBRuELCsyPUOfqXKEwnUxNwddGVhPP
# SIG # End signature block
