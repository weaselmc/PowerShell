$vms = Get-ClusterResource | ? {$_.Name -like "Virtual Machine DIPFA*"} | Get-VM

foreach ($vm in $vms)
{    
    $path = "C:\ClusterStorage\Volume5\$($vm.name)"
    Write-Host -ForegroundColor Magenta "Moving Storage for $($vm.name) to $path"
    Move-VMStorage -VM $vm -DestinationStoragePath  $path
}