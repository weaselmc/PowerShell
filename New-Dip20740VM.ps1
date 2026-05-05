    Param(   
        [Parameter (Mandatory=$true)]
        [String]$User,
        [String]$Group = "AWD7"
        )

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
username:s:Adatum\Administrator

"@
        #full address:s:NWSQLServer003
        if([string]::IsNullOrEmpty($IP)) {
            $rdpstring +=  "full address:s:$Server"
            }
        else {
            $rdpstring +=  "full address:s:$IP"
            }
        $outfile = $rdpstring | Out-File -FilePath "$Path\$Server.rdp"
        
}
    
    $Server = "20740C-LON-HOST1-$User"
    $SrcDir= "C:\ClusterStorage\Volume7\VHDs"
    $VMPath = "C:\ClusterStorage\Volume5"
    $VMServerPath = "$VMPath\$Server"
    $PPath = "$SrcDir\20740C-LON-HOST1.VHD"
    $MPPath = "$SrcDir\20740C-LON-HOST1-ALLFILES.VHDX"
    $FSPath = "\\Gondor\students$\$Group"
    $secpasswd = ConvertTo-SecureString "Pa55w.rd" -AsPlainText -Force
    $Cred = New-Object System.Management.Automation.PSCredential ("Adatum\Administrator", $secpasswd)


    Write-Host -ForegroundColor Green "Importing from $VMServerPath"
    #Create new VM and add VHD's
    New-VHD "$VMServerPath\Virtual Hard Disks\$Server.vhd" -Differencing -ParentPath $PPath
    New-VM -Name $Server -Path $VMPath -MemoryStartupBytes 16GB -VHDPath "$VMServerPath\Virtual Hard Disks\$Server.vhd" -Generation 1 -SwitchName "TDM Virtual Switch"
    #$vm = Import-VM -Path (Get-ChildItem "$VMServerPath\Virtual Machines" -Filter *.vmcx).FullName -Copy -GenerateNewId -SmartPagingFilePath "$VMServerPath\Virtual Machines" -SnapshotFilePath "$VMServerPath\Snapshots" -VhdDestinationPath "$VMServerPath\Virtual Hard Disks" -VirtualMachinePath "$VMServerPath\Virtual Machines"
    $vm = Get-VM $Server
    $vm | Set-VM -StaticMemory -ProcessorCount 4     
    #Add-VMNetworkAdapter -VMName $Server -SwitchName "Perimeter Virtual Switch" -DynamicMacAddress 
    $vmn = Get-VMNetworkAdapter -VMName $Server
    Set-VMNetworkAdapter $vmn[0] -MacAddressSpoofing On
    Set-VMNetworkAdapterVlan $vmn[0] -VlanId 10 -Access
    Set-VMNetworkAdapter $vmn[0] -DhcpGuard On
    
    #$vm | Set-VM -NewVMName $Server
    Get-VMProcessor -VMName $vm.Name | Set-VMProcessor -ExposeVirtualizationExtensions $true -CompatibilityForMigrationEnabled $true
    New-VHD "$VMServerPath\Virtual Hard Disks\$($Server)-AllFiles.vhdx" -Differencing -ParentPath $MPPath
    Add-VMHardDiskDrive -VMName $vm.Name -Path "$VMServerPath\Virtual Hard Disks\$($Server)-AllFiles.vhdx" -ControllerType SCSI -ControllerNumber 0 -ControllerLocation 1
    Add-VMToCluster -VMName $vm.Name
    Start-VM $vm
    $vmIP = $null
    While([string]::IsNullOrEmpty($vmIP))
    {
        try
        {
            $vmn = Get-VMNetworkAdapter $vm -ErrorAction Stop
            $vmIP = $vmn.IPAddresses[0]            
        } 
        catch
        { 
            Write-Host -ForegroundColor Yellow "Starting vm ..."
            Start-Sleep -Seconds 5
        }        
    }
    Write-Host -ForegroundColor Green "VM Found on $vmIP"
    #Read-Host "Set Administrator password before pressing enter!"
    #$num = [int]$Server.Substring($Server.Length-3)
    Invoke-Command -VMName $Server -Credential $Cred -ScriptBlock {       
        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server'-name "fDenyTSConnections" -Value 0
        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -name "UserAuthentication" -Value 0
        Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
        Get-NetFirewallRule -DisplayName "File and Printer Sharing*Echo*" | Enable-NetFirewallRule
        Set-Disk -Number 1 -IsOffline $false
        Set-Disk -Number 1 -IsReadOnly $false
        Update-VMVersion -VM (Get-VM 20740C-LON-NVHOST2) -Force
        Set-VMProcessor -VMName 20740C-LON-NVHOST2 -ExposeVirtualizationExtensions $true
        Get-VMNetworkAdapter -VMName 20740C-LON-NVHOST2 | Set-VMNetworkAdapter -MacAddressSpoofing On
        Set-VM -VMName 20740C-LON-NVHOST2 -MemoryStartupBytes 4GB
        Start-VM 20740C-LON-NVHOST2
        for ($i=0;$i -lt 20;$i++) {
            sleep -Seconds 1
            Write-Host -ForegroundColor Green "Starting VM ... $($i+1)"
        }
        $secpasswd = ConvertTo-SecureString "Pa55w.rd" -AsPlainText -Force
        $Cred = New-Object System.Management.Automation.PSCredential ("Adatum\Administrator", $secpasswd)
        Invoke-Command -VMName 20740C-LON-NVHOST2 -Credential $cred -ScriptBlock {
            Install-WindowsFeature -Name Hyper-V -IncludeAllSubFeature -IncludeManagementTools -Restart
        }
        #Install-WindowsFeature -ComputerName LON-NVHOST2 -Name Hyper-V -IncludeAllSubFeature -IncludeManagementTools -Restart                        
    }
    #Set-VMNetworkAdapterVlan -VMNetworkAdapter $vmn[0] -VlanId $VLanId -Access
    Stop-VM $Server -Force
    Checkpoint-VM $Server -SnapshotName "Starting Image"
    Start-VM $Server
    Move-ClusterVirtualMachineRole -Name $Server -Node "Bungo"
    New-RDPFile -Server $Server -IP $vmIP -Path "$FSPath\$User"    
    Write-Host -ForegroundColor Green "$Server RDP created for $vmIP in $FSPath\$User" 

    $Server = "20740C-LON-HOST2-$User"
    $SrcDir= "C:\ClusterStorage\Volume7\VHDs"
    $VMPath = "C:\ClusterStorage\Volume5"
    $VMServerPath = "$VMPath\$Server"
    $PPath = "$SrcDir\20740C-LON-HOST2.VHD"
    $MPPath = "$SrcDir\20740C-LON-HOST2-ALLFILES.VHDX"
    $FSPath = "\\Gondor\students$\$Group"
    $secpasswd = ConvertTo-SecureString "Pa55w.rd" -AsPlainText -Force
    $Cred = New-Object System.Management.Automation.PSCredential ("Adatum\Administrator", $secpasswd)


    Write-Host -ForegroundColor Green "Importing from $VMServerPath"
    #Create new VM and add VHD's
    New-VHD "$VMServerPath\Virtual Hard Disks\$Server.vhd" -Differencing -ParentPath $PPath
    New-VM -Name $Server -Path $VMPath -MemoryStartupBytes 16GB -VHDPath "$VMServerPath\Virtual Hard Disks\$Server.vhd" -Generation 1 -SwitchName "TDM Virtual Switch"
    #$vm = Import-VM -Path (Get-ChildItem "$VMServerPath\Virtual Machines" -Filter *.vmcx).FullName -Copy -GenerateNewId -SmartPagingFilePath "$VMServerPath\Virtual Machines" -SnapshotFilePath "$VMServerPath\Snapshots" -VhdDestinationPath "$VMServerPath\Virtual Hard Disks" -VirtualMachinePath "$VMServerPath\Virtual Machines"
    $vm = Get-VM $Server
    $vm | Set-VM -StaticMemory -ProcessorCount 4     
    #Add-VMNetworkAdapter -VMName $Server -SwitchName "Perimeter Virtual Switch" -DynamicMacAddress 
    $vmn = Get-VMNetworkAdapter -VMName $Server
    Set-VMNetworkAdapter $vmn[0] -MacAddressSpoofing On
    Set-VMNetworkAdapterVlan $vmn[0] -VlanId 10 -Access
    Set-VMNetworkAdapter $vmn[0] -DhcpGuard On
    
    #$vm | Set-VM -NewVMName $Server
    Get-VMProcessor -VMName $vm.Name | Set-VMProcessor -ExposeVirtualizationExtensions $true -CompatibilityForMigrationEnabled $true
    New-VHD "$VMServerPath\Virtual Hard Disks\$($Server)-AllFiles.vhdx" -Differencing -ParentPath $MPPath
    Add-VMHardDiskDrive -VMName $vm.Name -Path "$VMServerPath\Virtual Hard Disks\$($Server)-AllFiles.vhdx" -ControllerType SCSI -ControllerNumber 0 -ControllerLocation 1
    Add-VMToCluster -VMName $vm.Name
    Start-VM $vm
    $vmIP = $null
    While([string]::IsNullOrEmpty($vmIP))
    {
        try
        {
            $vmn = Get-VMNetworkAdapter $vm -ErrorAction Stop
            $vmIP = $vmn.IPAddresses[0]            
        } 
        catch
        { 
            Write-Host -ForegroundColor Yellow "Starting vm ..."
            Start-Sleep -Seconds 5
        }        
    }
    Write-Host -ForegroundColor Green "VM Found on $vmIP"
    #Read-Host "Set Administrator password before pressing enter!"
    #$num = [int]$Server.Substring($Server.Length-3)
    Invoke-Command -VMName $Server -Credential $Cred -ScriptBlock {       
        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server'-name "fDenyTSConnections" -Value 0
        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -name "UserAuthentication" -Value 0
        Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
        Get-NetFirewallRule -DisplayName "File and Printer Sharing*Echo*" | Enable-NetFirewallRule
        Set-Disk -Number 1 -IsOffline $false
        Set-Disk -Number 1 -IsReadOnly $false
    }
    #Set-VMNetworkAdapterVlan -VMNetworkAdapter $vmn[0] -VlanId $VLanId -Access
    Stop-VM $Server -Force
    Checkpoint-VM $Server -SnapshotName "Starting Image"
    Start-VM $Server
    Move-ClusterVirtualMachineRole -Name $Server -Node "Bungo"
    New-RDPFile -Server $Server -IP $vmIP -Path "$FSPath\$User"    
    Write-Host -ForegroundColor Green "$Server RDP created for $vmIP in $FSPath\$User"