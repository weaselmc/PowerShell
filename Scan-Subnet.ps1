param(
    [Parameter (Mandatory=$true)]
    [string] $Network
)

[system.net.ipaddress]::TryParse("$Network.0")
for($i=1; $i -lt 256; $i++){
    if (Test-Connection "$Network.$i" -Count 1 -Quiet){
        Write-Host "$Network.$i Up" -ForegroundColor Green
        
    }
    else {
        Write-Host "$Network.$i Down" -ForegroundColor Red
    }
}