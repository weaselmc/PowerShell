$vmn = Get-VMNetworkAdapter "DipNetS2FA001" -ComputerName drogo
foreach($n in $vmn){
    [VMNetVlan]$nic
    $nic.macaddress = $n.MACAdress
    $nic.vlanid = $n.vlansetting.vlanid
    $nic
    }

class VMNetVlan
{
    [string] $MACAddress
    [int] $VlanId
}