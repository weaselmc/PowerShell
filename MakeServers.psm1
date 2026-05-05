Function New-RDPFile{
<#
.SYNOPSIS
Creates RDP File connecting to a Server saved and a location.

.DESCRIPTION
Creates student accounts in the current domain with home directories in the specified location. 
Requires a Firstname, Lastname, ID and Group.

.PARAMETER Server
Student Server.

.PARAMETER Path
Student Path.

.EXAMPLE
New-RDPFile -Server ServerName -Path C:\RDPFiles

#>
    Param(
        [Parameter (Mandatory=$true)]
        [string]$Server,
        [Parameter (Mandatory=$true)]
        [string]$IP,
        [Parameter (Mandatory=$true)]
        [String]$Path)
        
        $rdpstring = @"
screen mode id:i:2
use multimon:i:0
desktopwidth:i:2560
desktopheight:i:1440
session bpp:i:32
winposstr:s:0,1,0,0,800,600
compression:i:1
keyboardhook:i:2
audiocapturemode:i:0
videoplaybackmode:i:1
connection type:i:7
networkautodetect:i:1
bandwidthautodetect:i:1
displayconnectionbar:i:1
enableworkspacereconnect:i:0
disable wallpaper:i:0
allow font smoothing:i:0
allow desktop composition:i:0
disable full window drag:i:1
disable menu anims:i:1
disable themes:i:0
disable cursor setting:i:0
bitmapcachepersistenable:i:1
audiomode:i:0
redirectprinters:i:1
redirectcomports:i:0
redirectsmartcards:i:1
redirectclipboard:i:1
redirectposdevices:i:0
autoreconnection enabled:i:1
authentication level:i:2
prompt for credentials:i:0
negotiate security layer:i:1
remoteapplicationmode:i:0
alternate shell:s:
shell working directory:s:
gatewayhostname:s:
gatewayusagemethod:i:4
gatewaycredentialssource:i:4
gatewayprofileusagemethod:i:0
promptcredentialonce:i:0
gatewaybrokeringtype:i:0
use redirection server name:i:0
rdgiskdcproxy:i:0
kdcproxyname:s:
drivestoredirect:s:
username:s:Administrator

"@
        #full address:s:NWSQLServer003

        $rdpstring +=  "full address:s:$IP"
        $outfile = $rdpstring | Out-File -FilePath "$Path\$Server.rdp"
        
} 

Function New-DipFASVM{
<#
.SYNOPSIS
Creates a storage Server instance for the Diploma Networking Assessment.

.DESCRIPTION
Creates a clustered VM with name of Server and sets up 4 networks adapters for Local access, SAN access and Management access.
Local Access has an ip address set to 192.168.VLAN.ServerNum/24. Management Access has an ip address set to 172.20.VLAN.ServerNum/16. 
SAN Access set to 172.16.1.(VLANId+30)/24 and 172.17.1.(VLANId+30)/24.

.PARAMETER Server
Server name for VM.

.PARAMETER User
User for RDP file creation.

.PARAMETER Group
Group user is in for RDP file creation

.PARAMETER VLanId
VLan that storage network will use. Needs to be between 300 and 399.

.PARAMETER AddDataDrives
Used to add 3 Local 64GB storage drivs for Scale Out Hyperconverged servers

.EXAMPLE
New-RDPFile -Server ServerName -Path C:\RDPFiles

#>
    Param(           
        [Parameter (Mandatory=$true)]
        [String]$User,
        [String]$Group = "AWD7",
        [string]$Server="DipNetS1FA-$User-SS",
        [int]$VLanId = 201,        
        [switch]$AddDataDrives=$false
        )

    $SrcDir= "C:\ClusterStorage\Volume7\VMs\DIPFA\*"
    $SrcDataVHDs= "C:\ClusterStorage\Volume7\VHDs\Data*"
    $VMPath = "C:\ClusterStorage\Volume5"
    $VMServerPath = "$VMPath\$Server"
    $PPath = "C:\ClusterStorage\Volume7\VHDs\WS2016_1802_64G.vhdx"
    $MPPath = "C:\ClusterStorage\Volume7\VHDs\media.vhdx"
    $FSPath = "\\Gondor\students$"
    $secpasswd = ConvertTo-SecureString "Pa55w.rd" -AsPlainText -Force
    $Cred = New-Object System.Management.Automation.PSCredential ("Administrator", $secpasswd)

    #if($CopyFromSource)
    #{   
    #    New-Item -Type Directory -Path $VMServerPath        
    #    Copy-Item $SrcDir -Destination $VMServerPath -Recurse
    #    Copy-Item $SrcDataVHDs -Destination "$VMServerPath\Virtual Hard Disks"
    #    Write-Host -ForegroundColor Green "$VMServerPath Copied."
    #}

    Write-Host -ForegroundColor Green "Importing from $VMServerPath"
    #Create new VM and add VHD's
    New-VHD "$VMServerPath\Virtual Hard Disks\$Server.vhdx" -Differencing -ParentPath $PPath
    New-VM -Name $Server -Path $VMPath -MemoryStartupBytes 4GB -VHDPath "$VMServerPath\Virtual Hard Disks\$Server.vhdx" -Generation 2 -SwitchName "TDM Virtual Switch"
    #$vm = Import-VM -Path (Get-ChildItem "$VMServerPath\Virtual Machines" -Filter *.vmcx).FullName -Copy -GenerateNewId -SmartPagingFilePath "$VMServerPath\Virtual Machines" -SnapshotFilePath "$VMServerPath\Snapshots" -VhdDestinationPath "$VMServerPath\Virtual Hard Disks" -VirtualMachinePath "$VMServerPath\Virtual Machines"
    $vm = Get-VM $Server
    $vm | Set-VM -DynamicMemory -ProcessorCount 2 -MemoryMinimumBytes 2Gb -MemoryMaximumBytes 8gb
    $vm | Set-VMProcessor -CompatibilityForMigrationEnabled $true
    Add-VMNetworkAdapter -VMName $Server -SwitchName "TDM Virtual Switch" -DynamicMacAddress
    Add-VMNetworkAdapter -VMName $Server -SwitchName "TDM Virtual Switch" -DynamicMacAddress
    Add-VMNetworkAdapter -VMName $Server -SwitchName "TDM Virtual Switch" -DynamicMacAddress
    $vmn = Get-VMNetworkAdapter -VMName $Server
    #Set-VMNetworkAdapter $vmn[0] -MacAddressSpoofing On
    Set-VMNetworkAdapterVlan $vmn[0] -VlanId $VLanId -Access
    Set-VMNetworkAdapterVlan $vmn[1] -VlanId ($VLanId+100) -Access
    Set-VMNetworkAdapterVlan $vmn[2] -VlanId ($VLanId+150) -Access
    Set-VMNetworkAdapter $vmn[3] -DhcpGuard On
    Set-VMNetworkAdapterVlan $vmn[3] -VlanId 10 -Access
    #adding Media Drive with install preq
    New-VHD "$VMServerPath\Virtual Hard Disks\$($Server)_Data.vhdx" -Differencing -ParentPath $MPPath
    Add-VMHardDiskDrive -VMName $vm.Name -Path "$VMServerPath\Virtual Hard Disks\$($Server)_Data.vhdx" -ControllerType SCSI -ControllerNumber 0
    #adding Storage Drive
    New-VHD "$VMServerPath\Virtual Hard Disks\Data_$i.vhdx" -Dynamic -SizeBytes 256Gb  
    Add-VMHardDiskDrive -VMName $vm.Name -Path "$VMServerPath\Virtual Hard Disks\Data_$i.vhdx" -ControllerType SCSI -ControllerNumber 0
    
    Add-VMToCluster -VMName $vm.Name     
    Start-VM $vm
    $vmIP = $false
    Write-Host -ForegroundColor Yellow "Starting vm ..." -NoNewline
    While($vmIP -eq $false)
    {        
        $vmn = Get-VMNetworkAdapter $vm
        $vmIP = $vmn.IPAddresses -match "172.20.*"
        if(!$vmIP) {
            Write-Host -ForegroundColor Yellow "." -NoNewline
            Start-Sleep -Seconds 5          
        }
               
    }
    #$num = [int]$Server.Substring($Server.Length-3)   
    $StaticIP = "172.20.$VlanId.50"
    Write-Host -ForegroundColor Green "VM Found on $vmIP changing to -> $StaticIP"
    #Read-Host "Set Administrator password before pressing enter!"
    Invoke-Command -VMName $Server -Credential $Cred -AsJob -ScriptBlock {               
        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server'-name "fDenyTSConnections" -Value 0
        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -name "UserAuthentication" -Value 0
        Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
        Get-NetFirewallRule -DisplayName "File and Printer Sharing*Echo*" | Enable-NetFirewallRule        
        Get-Disk | ? IsOffline | Set-Disk -IsOffline:$false
        Get-Disk | ? IsReadOnly | Set-Disk -IsReadOnly:$false
        Remove-Item "C:\unattend.xml"              
    }
   Foreach($nic in $vmn){                                
        Write-Host -ForegroundColor Cyan "$($nic.MacAddress)(DHCP Guard $($nic.DhcpGuard)) - $($nic.VlanSetting.AccessVlanId)"
        $DisableAdapter = $false
        if($nic.VlanSetting.AccessVlanId -eq 10)
        {
            $newname = "Management"
            $IPAddress = $StaticIP
            $pf=16
            #Set-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -IPAddress $IPAddress -PrefixLength 16
        }
        elseif($nic.VlanSetting.AccessVlanId -eq $VLanId)
        {
            $newname = "Local"
            $IPAddress = "192.168.$VLanId.50"
            $pf = 24
        }
        elseif($nic.VlanSetting.AccessVlanId -eq ($VLanId + 100))
        {   
            $newname = "SAN1"                 
            $IPAddress = "10.$VLanId.1.50"
            $pf = 24
        }
        elseif($nic.VlanSetting.AccessVlanId -eq $VLanId + 150)
        {
            $newname = "SAN2" 
            $IPAddress= "10.$VLanId.2.50"
            $pf = 24
        }
        elseif($nic.VlanSetting.AccessVlanId -eq 50)
        {
            $newname = "External"
            $DisableAdapter = $true
        }          

        Write-Host -ForegroundColor Cyan "$($nic.Name)[$($nic.InterfaceIndex)] => $IPAddress"
        Invoke-Command -VMName $Server -Credential $Cred -ArgumentList $nic.MacAddress,$IPAddress, $pf, $newname, $DisableAdapter -ScriptBlock {
            Param($mac,$ip, $pf, $name, $as)
            $adapter = Get-NetAdapter | ? { $_.MacAddress.replace("-","") -eq "$mac"}
            Write-Host -ForegroundColor Cyan "$($adapter.Name)[$($adapter.InterfaceIndex)] => $name"              
            $adapter | Rename-NetAdapter -NewName $name
            if ($as)
            {
                $adapter | Disable-NetAdapter -Confirm:$false
            }
            #elseif ((Get-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex) -like "172.20.*")
            #{
            #     Set-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -IPAddress $ip -PrefixLength $pf
            #}
            else
            {                    
                New-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -IPAddress $ip -PrefixLength $pf
            }
                 
        }
    }
    #Set-VMNetworkAdapterVlan -VMNetworkAdapter $vmn[0] -VlanId $VLanId -Access    
    Checkpoint-VM $VM -SnapshotName "Starting Image"
    Move-ClusterVirtualMachineRole -Name $Server -MigrationType Live
    New-RDPFile -Server $Server -IP $StaticIP -Path "$FSPath\$Group\$User"
    Write-Host -ForegroundColor Green "$Server RDP created for $StaticIP in $FSPath\$Group\$User" 
}

Function New-DipFAVM{
<#
.SYNOPSIS
Creates a clustered instance for the Diploma Networking Assessment.

.DESCRIPTION
Creates a clustered VM with name of Server and sets up 4 networks adapters for Local access, SAN access and Management access.
Local Access has an ip address set to 192.168.VLAN.ServerNum/24. Management Access has an ip address set to 172.20.VLAN.ServerNum/16. 
SAN Access set to 172.16.1.(VLANId+30)/24 and 172.17.1.(VLANId+30)/24.

.PARAMETER Server
Server name for VM.

.PARAMETER User
User for RDP file creation.

.PARAMETER Group
Group user is in for RDP file creation

.PARAMETER VLanId
VLan that local network will use. Needs to be between 201 and 299.

.PARAMETER AddDataDrives
Used to add 3 Local 64GB storage drivs for Scale Out Hyperconverged servers

.EXAMPLE
New-RDPFile -Server ServerName -Path C:\RDPFiles

#>
    Param(
        [Parameter (Mandatory=$true)]
        [string]$Server,   
        [Parameter (Mandatory=$true)]
        [String]$User,
        [String]$Group = "AWD7",
        [int]$VLanId = 201,        
        [switch]$AddDataDrives=$false
        )

    $SrcDir= "C:\ClusterStorage\Volume7\VMs\DIPFA\*"
    $SrcDataVHDs= "C:\ClusterStorage\Volume7\VHDs\Data*"
    $VMPath = "C:\ClusterStorage\Volume5"
    $VMServerPath = "$VMPath\$Server"
    $PPath = "C:\ClusterStorage\Volume7\VHDs\WS2016_1802_64G.vhdx"
    $MPPath = "C:\ClusterStorage\Volume7\VHDs\media.vhdx"
    $FSPath = "\\Gondor\students$"
    $secpasswd = ConvertTo-SecureString "Pa55w.rd" -AsPlainText -Force
    $Cred = New-Object System.Management.Automation.PSCredential ("Administrator", $secpasswd)

    #if($CopyFromSource)
    #{   
    #    New-Item -Type Directory -Path $VMServerPath        
    #    Copy-Item $SrcDir -Destination $VMServerPath -Recurse
    #    Copy-Item $SrcDataVHDs -Destination "$VMServerPath\Virtual Hard Disks"
    #    Write-Host -ForegroundColor Green "$VMServerPath Copied."
    #}

    Write-Host -ForegroundColor Green "Importing from $VMServerPath"
    #Create new VM and add VHD's
    New-VHD "$VMServerPath\Virtual Hard Disks\$Server.vhdx" -Differencing -ParentPath $PPath
    New-VM -Name $Server -Path $VMPath -MemoryStartupBytes 16GB -VHDPath "$VMServerPath\Virtual Hard Disks\$Server.vhdx" -Generation 2 -SwitchName "TDM Virtual Switch"
    #$vm = Import-VM -Path (Get-ChildItem "$VMServerPath\Virtual Machines" -Filter *.vmcx).FullName -Copy -GenerateNewId -SmartPagingFilePath "$VMServerPath\Virtual Machines" -SnapshotFilePath "$VMServerPath\Snapshots" -VhdDestinationPath "$VMServerPath\Virtual Hard Disks" -VirtualMachinePath "$VMServerPath\Virtual Machines"
    $vm = Get-VM $Server
    $vm | Set-VM -StaticMemory -ProcessorCount 4    
    #$vm | Set-VM -NewVMName $Server
    $vm | Set-VMProcessor -ExposeVirtualizationExtensions $true -CompatibilityForMigrationEnabled $true    
    Add-VMNetworkAdapter -VMName $Server -SwitchName "TDM Virtual Switch" -DynamicMacAddress
    Add-VMNetworkAdapter -VMName $Server -SwitchName "TDM Virtual Switch" -DynamicMacAddress
    Add-VMNetworkAdapter -VMName $Server -SwitchName "TDM Virtual Switch" -DynamicMacAddress
    Add-VMNetworkAdapter -VMName $Server -SwitchName "TDM Virtual Switch" -DynamicMacAddress
    $vmn = Get-VMNetworkAdapter -VMName $Server
    Set-VMNetworkAdapter $vmn[0] -MacAddressSpoofing On
    Set-VMNetworkAdapter $vmn[1] -MacAddressSpoofing On
    Set-VMNetworkAdapterVlan $vmn[0] -VlanId $VLanId -Access
    Set-VMNetworkAdapterVlan $vmn[1] -VlanId 50 -Access
    Set-VMNetworkAdapterVlan $vmn[2] -VlanId ($VLanId+100) -Access
    Set-VMNetworkAdapterVlan $vmn[3] -VlanId ($VLanId+150) -Access
    Set-VMNetworkAdapter $vmn[4] -DhcpGuard On
    Set-VMNetworkAdapterVlan $vmn[4] -VlanId 10 -Access
        
    if($AddDataDrives){
        New-VHD "$VMServerPath\Virtual Hard Disks\$($Server)_Data.vhdx" -Differencing -ParentPath $MPPath
        Add-VMHardDiskDrive -VMName $vm.Name -Path "$VMServerPath\Virtual Hard Disks\$($Server)_Data.vhdx" -ControllerType SCSI -ControllerNumber 0
        for($i=1;$i -le 4;$i++){
            New-VHD "$VMServerPath\Virtual Hard Disks\Data_$i.vhdx" -Dynamic -SizeBytes 64GB  
            Add-VMHardDiskDrive -VMName $vm.Name -Path "$VMServerPath\Virtual Hard Disks\Data_$i.vhdx" -ControllerType SCSI -ControllerNumber 0
        }
    }
    Add-VMToCluster -VMName $vm.Name
    Start-VM $vm
    $vmIP = $false
    Write-Host -ForegroundColor Yellow "Starting vm ..." -NoNewline
    While($vmIP -eq $false)
    {        
        $vmn = Get-VMNetworkAdapter $vm
        $vmIP = $vmn.IPAddresses -match "172.20.*"
        if(!$vmIP) {
            Write-Host -ForegroundColor Yellow "." -NoNewline
            Start-Sleep -Seconds 5          
        }
               
    }
    $SNum = [int]$Server.Substring($Server.Length-3)
    $StaticIP = "172.20.$VlanId.$SNum"
    Write-Host -ForegroundColor Green " VM Found on $vmIP changing to -> $StaticIP"
    #Read-Host "Set Administrator password before pressing enter!"
    Invoke-Command -AsJob -VMName $Server -Credential $Cred -ScriptBlock {
        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server'-name "fDenyTSConnections" -Value 0
        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -name "UserAuthentication" -Value 0
        Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
        Get-NetFirewallRule -DisplayName "File and Printer Sharing*Echo*" | Enable-NetFirewallRule       
        Get-Disk | ? IsOffline | Set-Disk -IsOffline:$false
        Remove-Item "C:\unattend.xml"              
    }
    #Can check MAC and assign addresses based on MAC pool ([0] -> Management, [1] -> External, [2,3] -> SAN, [4] TDM
    Foreach($nic in $vmn){                                
        Write-Host -ForegroundColor Cyan "$($nic.MacAddress)(DHCP Guard $($nic.DhcpGuard)) - $($nic.VlanSetting.AccessVlanId)"
        $DisableAdapter = $false
        if($nic.VlanSetting.AccessVlanId -eq 10)
        {
            $newname = "Management"
            $IPAddress = $StaticIP
            $pf=16
            #Set-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -IPAddress $IPAddress -PrefixLength 16
        }
        elseif($nic.VlanSetting.AccessVlanId -eq $VLanId)
        {
            $newname = "Local"
            $IPAddress = "192.168.$VLanId.$SNum"
            $pf = 24
        }
        elseif($nic.VlanSetting.AccessVlanId -eq ($VLanId + 100))
        {   
            $newname = "SAN1"                 
            $IPAddress = "10.$VLanId.1.$SNum"
            $pf = 24
        }
        elseif($nic.VlanSetting.AccessVlanId -eq $VLanId + 150)
        {
            $newname = "SAN2" 
            $IPAddress= "10.$VLanId.2.$SNum"
            $pf = 24
        }
        elseif($nic.VlanSetting.AccessVlanId -eq 50)
        {
            $newname = "External"
            $DisableAdapter = $true
        }          

        Write-Host -ForegroundColor Cyan "$($nic.Name)[$($nic.InterfaceIndex)] => $IPAddress"
        Invoke-Command -VMName $Server -Credential $Cred -ArgumentList $nic.MacAddress,$IPAddress, $pf, $newname, $DisableAdapter -ScriptBlock {
            Param($mac,$ip, $pf, $name, $as)
            $adapter = Get-NetAdapter | ? { $_.MacAddress.replace("-","") -eq "$mac"}
            Write-Host -ForegroundColor Cyan "$($adapter.Name)[$($adapter.InterfaceIndex)] => $name"              
            $adapter | Rename-NetAdapter -NewName $name
            if ($as)
            {
                $adapter | Disable-NetAdapter -Confirm:$false
            }
            #elseif ((Get-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex) -like "172.20.*")
            #{
            #     Set-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -IPAddress $ip -PrefixLength $pf
            #}
            else
            {                    
                New-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -IPAddress $ip -PrefixLength $pf
            }
                 
        }
    }
    #Set-VMNetworkAdapterVlan -VMNetworkAdapter $vmn[0] -VlanId $VLanId -Access    
    Checkpoint-VM $VM -SnapshotName "Starting Image"
    Move-ClusterVirtualMachineRole -Name $Server -MigrationType Live
    New-RDPFile -Server $Server -IP $StaticIP -Path "$FSPath\$Group\$User"
    Write-Host -ForegroundColor Green "$Server RDP created for $StaticIP in $FSPath\$Group\$User" 
}

Function Get-ServerNames{
    Param(
        [Parameter (Mandatory=$true)]
        [string]$Prefix,
        [Parameter (Mandatory=$true)]
        [int]$NumberofServers
        )
    
    $out=@()
    $vms = Get-ClusterResource -ErrorAction SilentlyContinue | ? {($_.OwnerGroup -like "$Prefix*")}
    
    if([string]::IsNullOrEmpty($vms)){        
        for($i =1; $i -le $NumberofServers; $i++){
            $out += "$($Prefix)00$i"
        }
    }
    else {
        $LastVM = $vms[$vms.Length-1].OwnerGroup.Name
        $NextVMNum = [int]$LastVM.Substring($LastVM.Length-3) + 1         
        for($i = $NextVMNum; $i -le $NumberofServers + $NextVMNum - 1; $i++){
            if($i -le 9){
                $out += "$($Prefix)00$i"
            }
            elseif($i -le 99){
                $out += "$($Prefix)0$i"
            }
            else {
                $out += "$($Prefix)$i"
            }
        }
    }

    return $out    
}

Function New-DipS1VMs{
    Param(
        [Parameter (Mandatory=$true)]
        [String]$User,
        [Parameter (Mandatory=$true)]
        [int]$VlanId
     )
    
    $Servers =  Get-ServerNames -Prefix "DipNetS1FA-$User-" -NumberofServers 2
    Foreach($server in $Servers){        
        Write-Host -ForegroundColor Green "Creating $Server."
        New-DipFAVM -Server $server -User $User -VLanId $VlanId        
    }   
    New-DipFASVM -User $User -VLanId $VlanId
}

Function New-DipS2VMs{
    Param(
        [Parameter (Mandatory=$true)]
        [String]$User,
        [Parameter (Mandatory=$true)]
        [int]$VlanId
     )
    
    $Servers =  Get-ServerNames -Prefix "DipNetS2FA-$User-" -NumberofServers 3
    Foreach($server in $Servers){        
        Write-Host -ForegroundColor Green "Creating $Server."
        New-DipFAVM -Server $server -User $User -VLanId $VlanId -AddDataDrives
    }
}

