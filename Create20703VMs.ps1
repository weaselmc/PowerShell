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
username:s:Adatum\Administrator

"@
        #full address:s:NWSQLServer003

        $rdpstring +=  "full address:s:$IP"
        $outfile = $rdpstring | Out-File -FilePath "$Path\$Server.rdp"
        
}

$cred = Get-Credential "Adatum\Administrator"

for($i=3; $i -le 5;$i++){
    if($i -le 9)
    {
        $s = "00" + $i
    }
    elseif ($i -le 99)
    {
        $s = "0" + $i
    }
    else
    {
        $s = $i
    }
    $SrcDir= "C:\ClusterStorage\Volume1\Source\20703-Host"
    $Server = "20703-Host$s"
    $VMPath = "C:\ClusterStorage\Volume1\StudentVMs"
    $VMServerPath = "$VMPath\$Server"    
    New-Item -Type Directory -Path $VMServerPath
    Copy-Item "$SrcDir\Virtual Hard Disks" -Destination $VMServerPath -Recurse
    $vm = New-VM -Name $Server -MemoryStartupBytes 16GB -SwitchName "20G-TDM Virtual Switch" -Generation 1 -Path $VMPath -VHDPath "$VMServerPath\Virtual Hard Disks\Base17C-WS16-1607.vhd" -BootDevice IDE
    #Add-VMHardDiskDrive -VMName $vm.Name -Path  "$VMServerPath\Virtual Hard Disks\Base17C-WS16-1607.vhd" -ControllerType IDE -ControllerNumber 0 -ControllerLocation 0
    Add-VMHardDiskDrive -VMName $vm.Name -Path  "$VMServerPath\Virtual Hard Disks\20703-1A-Host-Disk1.vhdx" -ControllerType SCSI -ControllerNumber 0 -ControllerLocation 0
    Set-VMNetworkAdapterVlan (Get-VMNetworkAdapter $vm) -Access -VlanId 10
    Set-VMProcessor (Get-VMProcessor $vm) -Count 4 -ExposeVirtualizationExtensions $true
    Start-VM $vm
    $vmIP = $null
    While([string]::IsNullOrEmpty($vmIP))
    {
        $vmn = Get-VMNetworkAdapter $vm
        $vmIP = $vmn.IPAddresses[0]
    }        
    Invoke-Command -VMName $vm.Name -Credential $cred -ScriptBlock { Get-Disk | Set-Disk -IsOffline $false }
    Add-VMToCluster -VMName $vm.Name
    New-RDPFile -Server $Server -IP $vmIP -Path "D:\HelpDesk\20703VMs\"

    Write-Host -ForegroundColor Cyan "$Server created."
}