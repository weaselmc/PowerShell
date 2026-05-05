Param(
        [Parameter (Mandatory=$true)]
        [String]$User,
        $Servers,
        [Parameter (Mandatory=$true)]
        [int]$VlanId,
        [switch]$CopyFromSource=$false)

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
        [string]$ServerNamePrefix,
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
username:s:.s\Administrator

"@
        #full address:s:NWSQLServer003

        $rdpstring +=  "full address:s:$IP"
        $outfile = $rdpstring | Out-File -FilePath "$Path\$ServerNamePrefix.rdp"
        
} 

Function New-DipFAVM{
    Param(
        [Parameter (Mandatory=$true)]
        [string]$ServerName,   
        [Parameter (Mandatory=$true)]
        [String]$User,
        [String]$Group = "AWD7",
        [int]$VLanId = 70,        
        [switch]$CopyFromSource=$false
        )

    $SrcDir= "C:\ClusterStorage\Volume7\VMs\DIPFA\*"
    $SrcDataVHDs= "C:\ClusterStorage\Volume7\VHDs\Data*"
    $VMPath = "C:\ClusterStorage\Volume5"
    $VMServerPath = "$VMPath\$ServerName"
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
    New-VHD "$VMServerPath\Virtual Hard Disks\$ServerName.vhdx" -Differencing -ParentPath $PPath
    
    New-VM -Name $ServerName -Path $VMPath -MemoryStartupBytes 16GB -VHDPath "$VMServerPath\Virtual Hard Disks\$ServerName.vhdx" -Generation 2 -SwitchName "TDM Virtual Switch"
    #$vm = Import-VM -Path (Get-ChildItem "$VMServerPath\Virtual Machines" -Filter *.vmcx).FullName -Copy -GenerateNewId -SmartPagingFilePath "$VMServerPath\Virtual Machines" -SnapshotFilePath "$VMServerPath\Snapshots" -VhdDestinationPath "$VMServerPath\Virtual Hard Disks" -VirtualMachinePath "$VMServerPath\Virtual Machines"
    $vm = Get-VM $ServerName
    $vm | Set-VM -StaticMemory -ProcessorCount 4     
    Add-VMNetworkAdapter -VMName $ServerName -SwitchName "TDM Virtual Switch" -DynamicMacAddress
    Add-VMNetworkAdapter -VMName $ServerName -SwitchName "TDM Virtual Switch" -DynamicMacAddress
    Add-VMNetworkAdapter -VMName $ServerName -SwitchName "TDM Virtual Switch" -DynamicMacAddress
    Add-VMNetworkAdapter -VMName $ServerName -SwitchName "TDM Virtual Switch" -DynamicMacAddress
    $vmn = Get-VMNetworkAdapter -VMName $ServerName
    Set-VMNetworkAdapter $vmn[0] -MacAddressSpoofing On
    Set-VMNetworkAdapterVlan $vmn[0] -VlanId $VLanId -Access
    Set-VMNetworkAdapterVlan $vmn[1] -VlanId 50 -Access
    Set-VMNetworkAdapterVlan $vmn[2] -VlanId 150 -Access
    Set-VMNetworkAdapterVlan $vmn[3] -VlanId 150 -Access
    Set-VMNetworkAdapter $vmn[4] -DhcpGuard On
    Set-VMNetworkAdapterVlan $vmn[4] -VlanId 10 -Access
    
    #$vm | Set-VM -NewVMName $Server
    Get-VMProcessor -VMName $vm.Name | Set-VMProcessor -ExposeVirtualizationExtensions $true -CompatibilityForMigrationEnabled $true
    New-VHD "$VMServerPath\Virtual Hard Disks\$($Server)_Data.vhdx" -Differencing -ParentPath $MPPath
    Add-VMHardDiskDrive -VMName $vm.Name -Path "$VMServerPath\Virtual Hard Disks\$($Server)_Data.vhdx" -ControllerType SCSI -ControllerNumber 0 -ControllerLocation 1
    New-VHD "$VMServerPath\Virtual Hard Disks\Data_1.vhdx" -Dynamic -SizeBytes 64GB
    New-VHD "$VMServerPath\Virtual Hard Disks\Data_2.vhdx" -Dynamic -SizeBytes 64GB
    New-VHD "$VMServerPath\Virtual Hard Disks\Data_3.vhdx" -Dynamic -SizeBytes 64GB    
    Add-VMHardDiskDrive -VMName $vm.Name -Path "$VMServerPath\Virtual Hard Disks\Data_1.vhdx" -ControllerType SCSI -ControllerNumber 0 -ControllerLocation 2
    Add-VMHardDiskDrive -VMName $vm.Name -Path "$VMServerPath\Virtual Hard Disks\Data_2.vhdx" -ControllerType SCSI -ControllerNumber 0 -ControllerLocation 3
    Add-VMHardDiskDrive -VMName $vm.Name -Path "$VMServerPath\Virtual Hard Disks\Data_3.vhdx" -ControllerType SCSI -ControllerNumber 0 -ControllerLocation 4
    Add-VMToCluster -VMName $vm.Name
    Start-VM $vm
    $vmIP = $null
    While([string]::IsNullOrEmpty($vmIP))
    {
        try
        {
            $vmn = Get-VMNetworkAdapter $vm -ErrorAction Stop
            $vmIP = $vmn.IPAddresses[8]            
        } 
        catch
        { 
            Write-Host -ForegroundColor Yellow "Starting vm ..."
            Start-Sleep -Seconds 5
        }        
    }
    Write-Host -ForegroundColor Green "VM Found on $vmIP"
    Read-Host "Set Administrator password before pressing enter!"
    Invoke-Command -VMName $Server -Credential $Cred -ArgumentList (,$vmn) -ScriptBlock {       
        Param($nics)
        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server'-name "fDenyTSConnections" -Value 0
        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -name "UserAuthentication" -Value 1
        Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
        Get-NetFirewallRule -DisplayName "File and Printer Sharing*Echo*" | Enable-NetFirewallRule
        Foreach($nic in $nics)
        {
            $Mac = "$($nic.MacAddress[0])$($nic.MacAddress[1])-$($nic.MacAddress[2])$($nic.MacAddress[3])-$($nic.MacAddress[4])$($nic.MacAddress[5])-$($nic.MacAddress[6])$($nic.MacAddress[7])-$($nic.MacAddress[8])$($nic.MacAddress[9])-$($nic.MacAddress[10])$($nic.MacAddress[11])"  
            Write-Host -ForegroundColor Cyan $Mac
            $adapter = Get-NetAdapter | ? { $_.MacAddress -eq "$Mac"}
            $newname = $nic.SwitchName.Split(" ")[0]
            if(($newname -eq "TDM") -and ($nic.VlanSetting.AccessVlanId -ne 10))
            {
                $newname = "Local"
            }
            $adapter | Rename-NetAdapter -NewName $newname       
            Remove-Item "C:\unattend.xml" 
        }              
    }
    #Set-VMNetworkAdapterVlan -VMNetworkAdapter $vmn[0] -VlanId $VLanId -Access
    #Set-NetIPAddress
    Checkpoint-VM $ServerName -SnapshotName "Starting Image"
    New-RDPFile -Server $ServerName -IP $vmIP -Path "$FSPath\$Group\$User"
    Write-Host -ForegroundColor Green "$Server RDP created for $vmIP in $FSPath\$Group\$User"   

}

Function Get-NextDipFAVMNames{
    $vms = Get-ClusterResource -ErrorAction SilentlyContinue | ? {($_.OwnerGroup -like "DipNetS2FA0*")}
    if([string]::IsNullOrEmpty($vms)){
        $out = "DipNetS2FA001","DipNetS2FA002","DipNetS2FA003"
    }
    else {
        $LastVM = $vms[$vms.Length-1].OwnerGroup.Name
        $i = [int]$LastVM.Substring($LastVM.Length-3) + 1
        $j = $i+1
        $k = $i+2
        if($i -le 9){
            $out = "DipNetS2FA00$i"
        }
        elseif($i -le 99){
            $out = "DipNetS2FA0$i"
        }
        else {
            $out = "DipNetS2FA$i"
        }

        if($j -le 9){
            $out = $out, "DipNetS2FA00$j"
        }
        elseif($j -le 99){
            $out = $out, "DipNetS2FA0$j"
        }
        else {
            $out = $out, "DipNetS2FA$j"
        }

        if($k -le 9){
            $out = $out, "DipNetS2FA00$k"
        }
        elseif($k -le 99){
            $out = $out, "DipNetS2FA0$k"
        }
        else {
            $out = $out, "DipNetS2FA$k"
        }
    }
    return $out
}

#$Cred = Get-Credential "Administrator"
if([string]::IsNullOrEmpty($Servers))
{
    $Servers =  Get-NextDipFAVMNames
}

Foreach($server in $Servers){
    if($CopyFromSource)
    {
        Write-Host -ForegroundColor Green "Copying $Server from source."        
        }
    else
    {    
        Write-Host -ForegroundColor Green "Not copying $Server from source."        
        }
    New-DipFAVM -Server $server -User $User -VLanId $VlanId -CopyFromSource:$CopyFromSource
}