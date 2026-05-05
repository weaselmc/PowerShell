$VDSwitch = "DSwitch"
$VLan = 75
$S = "*CS*WILKIJ"

for ($i=0;$i -lt 2;$i++){                
    $VLanId = $VLan+$i
    $vdpname = "Vlan$($VLanId)DPortGroup"
    $vdp = $null
    $vdp = Get-VDPortgroup -Name $vdpname -ErrorAction SilentlyContinue
    if([string]::IsNullOrEmpty($vdp)){
        New-VDPortgroup -VDSwitch $VDSwitch -Name $vdpname -VlanId $VLanId -PortBinding Ephemeral -NumPorts 8
        Get-VDPortgroup $vdpname | Get-VDSecurityPolicy |  Set-VDSecurityPolicy -AllowPromiscuous $true -ForgedTransmits $true -MacChanges $true                  
    }
}

foreach( $vm in (get-vm $s)) {
    New-NetworkAdapter -VM $vm -StartConnected:$true -NetworkName "Vlan$($VLan)DPortGroup" -Type Vmxnet3 -Confirm:$false
    New-NetworkAdapter -VM $vm -StartConnected:$true -NetworkName "Vlan$($VLan+1)DPortGroup" -Type Vmxnet3 -Confirm:$false
    New-NetworkAdapter -VM $vm -StartConnected:$false -NetworkName "External_DPG" -Type Vmxnet3 -Confirm:$false
}