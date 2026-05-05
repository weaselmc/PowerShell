param(
    [Parameter (Mandatory=$true)]
    [string] $Room
)

$cred = Get-Credential "TDM\Buttsm.Admin"

for($i=1; $i -lt 10; $i++){
    #$computer = "$Room-0$i-svr"
    #$s = New-CimSession -ComputerName $computer -Credential $cred
    $ip = Get-NetIPAddress -CimSession $s
    if (Test-Connection "$Room-0$i-svr" -Count 1 -Quiet){        
        Write-Host "$Room-0$i-svr Up" -ForegroundColor Green
    }
    else {
        Write-Host "$Room-0$i-svr Down" -ForegroundColor Red
    }
}

for($i=10; $i -lt 26; $i++){
    if (Test-Connection "$Room-$i-svr" -Count 1 -Quiet){
        Write-Host "$Room-0$i-svr Up" -ForegroundColor Green
    }
    else {
        Write-Host "$Room-$i-svr Down" -ForegroundColor Red
    }
}