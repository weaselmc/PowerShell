$VMs = get-VM *-RBFE-DD-WRT
foreach ($VM in $VMs) {
    $VMName = $VM.Name
    $Folder = $VM.Folder
    $User = $VMName.substring(0,6)
    $CS = get-vm "$User-RBFE-CS1"
    $CsNa = Get-NetworkAdapter -VM $CS
    if("$Folder" -eq "NetDipStage2"){
        $PortGroup = $csNA[1].NetworkName
    }
    else{
        $PortGroup = $csNA[0].NetworkName
    }    
    #"$VMName $Folder $User $PortGroup " + ("$Folder" -eq "NetDipStage2")
    $WrtNA = Get-NetworkAdapter -VM $VM
    New-VIPermission -Entity "$VMName" -Principal "TDM\$User" -Role "VirtualMachineConsoleUser" -Propagate $true    
    Set-NetworkAdapter -NetworkAdapter $WrtNA[0] -Portgroup $PortGroup -Confirm:$false
    Set-NetworkAdapter -NetworkAdapter $WrtNA[1] -Portgroup "dpgExternal" -Confirm:$false
}