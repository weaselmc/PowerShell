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
username:s:.s\Administrator

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

Function New-DipFAVM{
    Param(
        [Parameter (Mandatory=$true)]
        [string]$Server,   
        [Parameter (Mandatory=$true)]
        [String]$User,
        [String]$Group = "AWD7"
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
    Add-VMNetworkAdapter -VMName $Server -SwitchName "TDM Virtual Switch" -DynamicMacAddress
    Add-VMNetworkAdapter -VMName $Server -SwitchName "TDM Virtual Switch" -DynamicMacAddress
    Add-VMNetworkAdapter -VMName $Server -SwitchName "TDM Virtual Switch" -DynamicMacAddress
    Add-VMNetworkAdapter -VMName $Server -SwitchName "TDM Virtual Switch" -DynamicMacAddress
    $vmn = Get-VMNetworkAdapter -VMName $Server
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
    $num = [int]$Server.Substring($Server.Length-3)
    Invoke-Command -VMName $Server -Credential $Cred -ArgumentList (,$vmn),"172.20.$VlanId.$num" -ScriptBlock {       
        Param($nics,$IPAddress)
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
            if($nic.VlanSetting.AccessVlanId -eq 10)
            {
                $newname = "Management"
                Set-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -IPAddress $IPAddress -PrefixLength 16
            }
            elseif($nic.VlanSetting.AccessVlanId -eq $Vlan)
            {
                $newname = "Local"
            }
            elseif($nic.VlanSetting.AccessVlanId -eq 50)
            {
                $newname = "External"
            }
            elseif($nic.VlanSetting.AccessVlanId -eq 150)
            {
                $newname = "SAN" + $nic.MacAddress
            }
            
            $adapter | Rename-NetAdapter -NewName $newname       
        }
        Remove-Item "C:\unattend.xml"              
    }
    #Set-VMNetworkAdapterVlan -VMNetworkAdapter $vmn[0] -VlanId $VLanId -Access
    #Set-NetIPAddress -
    Checkpoint-VM $Server -SnapshotName "Starting Image"
    New-RDPFile -Server $Server -IP $vmIP -Path "$FSPath\$Group\$User"
    Write-Host -ForegroundColor Green "$Server RDP created for $vmIP in $FSPath\$Group\$User"   

}
Function Get-NextDipFAVMNames{
    $vms = Get-ClusterResource -ErrorAction SilentlyContinue | ? {($_.OwnerGroup -like "DIPFA0*")}
    if([string]::IsNullOrEmpty($vms)){
        $out = "DipFA001","DipFA002"
    }
    else {
        $LastVM = $vms[$vms.Length-1].OwnerGroup.Name
        $i = [int]$LastVM.Substring($LastVM.Length-3) + 1
        $j = $i+1
        if($i -le 9){
            $out = "DipFA00$i"
        }
        elseif($i -le 99){
            $out = "DipFA0$i"
        }
        else {
            $out = "DipFA$i"
        }

        if($j -le 9){
            $out = $out, "DipFA00$j"
        }
        elseif($j -le 99){
            $out = $out, "DipFA0$j"
        }
        else {
            $out = $out, "DipFA$j"
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
        New-DipFAVM -Server $server -User $User -VLanId $VlanId -CopyFromSource:$CopyFromSource
        }
    else
    {    
        Write-Host -ForegroundColor Green "Not copying $Server from source."
        New-DipFAVM -Server $server -User $User -VLanId $VlanId -CopyFromSource:$CopyFromSource
        }
}