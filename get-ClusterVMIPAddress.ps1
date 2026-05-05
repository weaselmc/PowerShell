$nics = Get-ClusterResource | ? { $_.ResourceType -eq "Virtual Machine" -and $_.State -eq "Online"} | Get-VM | Get-VMNetworkAdapter

