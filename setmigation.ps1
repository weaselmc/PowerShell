$vms = Get-ClusterResource | ? {($_.OwnerGroup -like "MSSQL*") -or ($_.OwnerGroup -like "HD*")}
Foreach ($vm in $vms)
{
    $state = $vm.State
    $p = Get-VMProcessor $vm.OwnerGroup -ComputerName $vm.OwnerNode
    Stop-VM $vm.OwnerGroup -ComputerName $vm.OwnerNode
    while ((get-VM $vm.OwnerGroup -ComputerName $vm.OwnerNode).state -ne "Off")
    {
    }
    Set-VMProcessor $p -CompatibilityForMigrationEnabled $true
    if( $state -eq "Online")
    {
        Start-VM $vm.OwnerGroup -ComputerName $vm.OwnerNode
    }
    Write-Host "$vm.OwnerGroup migration settigns updated"
} 