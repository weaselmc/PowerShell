$VMs = get-VM "*-RBFE-DD-WRT"
foreach ($VM in $VMs) {
    $User = "$($VM.Name.substring(0,6))" #TDM\
    #New-VIPermission -Entity $vm.Name -Principal $User -Role "VirtualMachineUser" -Propagate $true
    $na = VMware.VimAutomation.Core\Get-NetworkAdapter -VM $VM
    $PortGroup0 = $na[0].NetworkName
    $PortGroup1 = $na[1].NetworkName
    
    if("$PortGroup0" -eq "$PortGroup1" ){        
        $ClVm = get-vm "$user-RBFE-CL1"
        if($null -ne $ClVm){
            $PortGroup = (Get-NetworkAdapter $ClVm)[1].NetworkName
            Write-Host "Swapping $($vm.Name) on pg $PortGroup" -ForegroundColor Yellow
            Set-NetworkAdapter -NetworkAdapter $na[0] -Portgroup "dpgExternal" -Confirm:$false
            Set-NetworkAdapter -NetworkAdapter $na[1] -Portgroup $PortGroup -Confirm:$false        
        }
        else {
            Write-Host "No Client for $($vm.Name) " -ForegroundColor red
        }
        
    }
    else {
        Write-Host "$($vm.Name) already swapped" -ForegroundColor Green
    }
    $ClVm = $null
}
