$vms = Get-ClusterResource | ? {$_.ResourceType -eq "Virtual Machine" -and $_.Name -like "*SS" -and $_.State -eq "Online"} | get-vm

Foreach($vm in $vms){
    Stop-VM $vm
    $vm | Set-VM -DynamicMemory -MemoryMinimumBytes 2gb -MemoryMaximumBytes 8gb -MemoryStartupBytes 4gb
    $vm | Set-VMProcessor -CompatibilityForMigrationEnabled $true -Count 2
    start-vm $vm
}