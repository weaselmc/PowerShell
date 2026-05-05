Foreach($nic in $vmn){                                
    Write-Host -ForegroundColor Cyan "$($nic.MacAddress)(DHCP Guard $($nic.DhcpGuard)) - $($nic.VlanSetting.AccessVlanId)"
    $DisableAdapter = $false
    if($nic.VlanSetting.AccessVlanId -eq 10)
    {
        $newname = "Management"
        $IPAddress = $StaticIP
        $pf=16
        #Set-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -IPAddress $IPAddress -PrefixLength 16
    }
    elseif($nic.VlanSetting.AccessVlanId -eq $VLanId)
    {
        $newname = "Local"
        $IPAddress = "192.168.$VLanId.$SNum"
        $pf = 24
    }
    elseif($nic.VlanSetting.AccessVlanId -eq ($VLanId + 100))
    {   
        $newname = "SAN1"                 
        $IPAddress = "10.10.$VLanId.$([int]$SNum+1)"
        $pf = 24
    }
    elseif($nic.VlanSetting.AccessVlanId -eq $VLanId + 150)
    {
        $newname = "SAN2" 
        $IPAddress = "10.10.$($VLanId+1).$([int]$SNum+1)"
        $pf = 24
    }
    elseif($nic.VlanSetting.AccessVlanId -eq 50)
    {
        $newname = "External"
        $DisableAdapter = $true
    }

    "$($nic.MacAddress),$IPAddress, $pf, $newname, $DisableAdapter"
}