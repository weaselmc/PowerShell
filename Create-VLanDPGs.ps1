$VLan = 381
$VDSwitch = "DSwitch"

for ($i=0;$i -le 2;$i++){                
    $VLanId = $VLan+$i
    $vdpname = "Vlan$($VLanId)DPortGroup"
    $vdp = $null
    $vdp = Get-VDPortgroup -Name $vdpname -ErrorAction SilentlyContinue
    if([string]::IsNullOrEmpty($vdp)){
        New-VDPortgroup -VDSwitch $VDSwitch -Name $vdpname -VlanId $VLanId -PortBinding Ephemeral -NumPorts 8
        #Get-VDPortgroup $vdpname | Get-VDSecurityPolicy |  Set-VDSecurityPolicy -AllowPromiscuous $true -ForgedTransmits $true -MacChanges $true
        Set-MacLearn -DVPortgroupName $vdpname -EnableMacLearn $true -EnablePromiscuous $false -EnableForgedTransmit $true -EnableMacChange $false                  
    }
}