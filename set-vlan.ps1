$Vlan = 110
$VDSwitch = "DSwitch"
#$users = "WHITBE", "FOWLEL", "PERRYD", "ALMEHF", "CRAIGE", "STIRLC", "RICHLU"
$users = get-adgroupmember BCZ09 | get-aduser | select -ExpandProperty SamAccountName
$Servers = "RBFE-SS", "RBFE-DD-WRT", "RBFE-CS1", "RBFE-CS2", "RBFE-CL1"
foreach($user in $users){    
    for ($i=0;$i -le 2;$i++){                
        $VLanId = $VLan+$i
        $vdpname = "Vlan$($VLanId)DPortGroup"
        $vdp = $null
        $vdp = Get-VDPortgroup -Name $vdpname -ErrorAction SilentlyContinue
        if([string]::IsNullOrEmpty($vdp)){
            New-VDPortgroup -VDSwitch $VDSwitch -Name $vdpname -VlanId $VLanId -PortBinding Ephemeral #-NumPorts 8
            #Get-VDPortgroup $vdpname | Get-VDSecurityPolicy |  Set-VDSecurityPolicy -AllowPromiscuous $true -ForgedTransmits $true -MacChanges $true
            Set-MacLearn -DVPortgroupName $vdpname -EnableMacLearn $true -EnablePromiscuous $false -EnableForgedTransmit $true -EnableMacChange $false
        }
    }
    foreach ($Server in $Servers) {
        $VMName = "$User-$Server"
        $vm = Get-VM $VMName
        #VMware.VimAutomation.Core\stop-vm $vm -Confirm:$false
        $na = VMware.VimAutomation.Core\Get-NetworkAdapter -VM $vm
        if($Server -like "RBFE-CS*"){            
            Set-NetworkAdapter -NetworkAdapter $na[0] -Portgroup "Vlan$($VLan)DPortGroup" -Confirm:$false
            Set-NetworkAdapter -NetworkAdapter $na[1] -Portgroup "Vlan$($VLan+1)DPortGroup"  -Confirm:$false
            Set-NetworkAdapter -NetworkAdapter $na[2] -Portgroup "Vlan$($VLan+2)DPortGroup"  -Confirm:$false
            Set-NetworkAdapter -NetworkAdapter $na[3] -Portgroup "dpgExternal" -Confirm:$false
            Set-NetworkAdapter -NetworkAdapter $na[3] -StartConnected:$true -Confirm:$false                  
        }
        elseif($Server -eq "RBFE-CL1"){
            Set-NetworkAdapter -NetworkAdapter $na[1] -Portgroup "Vlan$($VLan)DPortGroup" -Confirm:$false
        }
        elseif($Server -eq "RBFE-SS"){
            Set-NetworkAdapter -NetworkAdapter $na[0] -Portgroup "Vlan$($VLan)DPortGroup" -Confirm:$false
            Set-NetworkAdapter -NetworkAdapter $na[1] -Portgroup "Vlan$($VLan+1)DPortGroup" -Confirm:$false
            Set-NetworkAdapter -NetworkAdapter $na[2] -Portgroup "Vlan$($VLan+2)DPortGroup" -Confirm:$false
        }
        else{
            Set-NetworkAdapter -NetworkAdapter $na[0] -Portgroup "Vlan$($VLan)DPortGroup" -Confirm:$false
            Set-NetworkAdapter -NetworkAdapter $na[1] -Portgroup "dpgExternal" -Confirm:$false
        }
        New-Snapshot -VM $vm  -name "Starting Image" -Confirm:$false -RunAsync:$true
    }
    $Vlan = $Vlan+3
}