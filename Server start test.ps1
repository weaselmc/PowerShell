$start = Get-Date
$vms = Get-ClusterResource | ? {($_.OwnerGroup -like "MSSQL*") -and ($_.State -eq "Offline")}
    $Server = $vms[0]
    Start-ClusterResource $Server
    Enter-PSSession $Server.OwnerGroup
    $end = Get-Date
    $time = $end - $start
    write-host "Server started in $time" -ForegroundColor Cyan