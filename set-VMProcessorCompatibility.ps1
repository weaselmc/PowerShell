 $VMs = Get-ClusterResource | Get-VM
 ForEach($VM in $VMs)
 {
    if((Get-VMProcessor $VM).CompatibilityForMigrationEnabled -eq $false)
    {
        if($VM.State -eq "Running")
        {
            Write-Host -ForegroundColor DarkCyan "Stopping $VM"
            Stop-VM $VM
            Write-Host -ForegroundColor DarkCyan "Changing $VM Compatibility"
            Set-VMProcessor $VM -CompatibilityForMigrationEnabled $true
            Write-Host -ForegroundColor DarkCyan "Starting $VM"
            Start-VM $VM
        }
        else
        {
            Write-Host -ForegroundColor DarkCyan "Changing $VM Compatibility"
            Set-VMProcessor $VM -CompatibilityForMigrationEnabled $true
        }
    }
 }