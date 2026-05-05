$dswitch = "DSwitch"

for ($vlanid = 300;$vlanid -lt 500;$vlanid+=10){
    $dpg = "VLan$($vlanid)DPortGroup"
    New-VDPortgroup -VDSwitch $dswitch -Name $dpg -VlanId $vlanid -PortBinding Ephemeral -NumPorts 8
    Get-VDPortgroup $dpg | Get-VDSecurityPolicy |  Set-VDSecurityPolicy -AllowPromiscuous $true -ForgedTransmits $true -MacChanges $true
}