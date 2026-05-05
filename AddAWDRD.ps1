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
    Param([
        Parameter (Mandatory=$true)]
        [string]$Server ,
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

"@
        #full address:s:NWSQLServer003

        $rdpstring +=  "full address:s:$Server"
        $outfile = $rdpstring | Out-File -FilePath "$Path\$Server.rdp"
        
}

Function Add-StudentVMAccess{
 Param(
        [Parameter (Mandatory=$true)]
        [string]$Username,
        [Parameter (Mandatory=$true)]
        [string]$Group,
        [Parameter (Mandatory=$true)]
        [string]$Server )

    $Domain = Get-ADDomain
    #$vms = Get-ClusterResource | ? {($_.OwnerGroup -like "MSSQL*") -and ($_.State -eq "Offline")}
    #$Server = $vms[0]
    $SAMUser =   "$($Domain.NetBIOSName)\$Username"
    Start-ClusterResource $Server
    start-sleep -Seconds 
    Invoke-Command -ComputerName $Server -ArgumentList $SAMUser -ScriptBlock { 
        param($uname)

        Add-LocalGroupMember -Group "Remote Desktop Users" -Member $uname

        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server'-name "fDenyTSConnections" -Value 0
        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -name "UserAuthentication" -Value 1
        Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
        }
    New-RDPFile -Server $Server -Path "\\Frodo\Students$\$Group\$Username" -ErrorAction SilentlyContinue
    Write-Host -ForegroundColor Green "created \\Frodo\Students$\$Group\$Username\$Server.rdp"

}

$Users = Get-ChildItem E:\AWE6
Foreach($user in $Users){
    $Server = (Get-ChildItem $user.FullName -Filter "MSSQL*").Name.Split(".")[0]
    $Group = "AWE6"
    $Username = $user.Name
    Add-StudentVMAccess -Username $Username -Group $Group -Server $Server
}
