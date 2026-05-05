Get-ClusterResource | ? { $_.ResourceType -eq "Virtual Machine" -and $_.Name -like "*MSSQL*"} | % {
    $vm = Get-VM $_
    if (($vm | Get-VMProcessor).CompatibilityForMigrationEnabled -eq $false){
        Write-Host -ForegroundColor Green "Changing $($vm.Name)"
        Stop-VM $vm
        $vm | Set-VMProcessor -CompatibilityForMigrationEnabled $true
        Start-VM $vm
        } 
    }