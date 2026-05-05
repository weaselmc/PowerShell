$VMs = get-VM *-RBFE-DD-WRT
foreach ($VM in $VMs) {
    $VMName = $VM.Name
    $Folder = $VM.Folder
    $na = Get-NetworkAdapter -VM $VM
    if([string]::Compare($Folder,"CyberAdvDip") -eq 0){
        $Store = "Cyber_Datastore"
    }
    else{
        $Store = "Net_Datastore"
    }
        
    if($na[0].NetworkName -eq "dpgExternal"){
        $PortGroup = $na[1].NetworkName
    }
    else {
        $PortGroup = $na[0].NetworkName
    }
    Write-host "New-VM -Template "RBFE-DD-WRT" -Name $VMName -Datastore $Store -Location $Folder -ResourcePool Resources -RunAsync"
    #Stop-VM -VM $vm -Confirm:$false
    Remove-VM -VM $vm -Confirm:$false
    $NewVM = VMware.VimAutomation.Core\New-VM -Template "RBFE-DD-WRT" -Name $VMName -Datastore $Store -Location $Folder -ResourcePool Resources -RunAsync
    $NewVMTask = Get-Task -ID $NewVM.id
    while($NewVMTask -eq "Running")
    {
        Start-Sleep 5
        $NewVMTask = Get-Task -ID $NewVM.id
    }
    #$NewVM = get-vm $ServerName
    Write-host "Set-NetworkAdapter -Portgroup $PortGroup -Confirm:$false"
    $na = VMware.VimAutomation.Core\Get-NetworkAdapter -VM $NewVM
    Set-NetworkAdapter -NetworkAdapter $na[0] -Portgroup $PortGroup -Confirm:$false
    Set-NetworkAdapter -NetworkAdapter $na[1] -Portgroup "dpgExternal" -Confirm:$false
}