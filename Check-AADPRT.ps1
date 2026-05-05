<#
    Hybrid Join + PRT Validation Script
    Performs WAM Reset if device is NOT hybrid joined or PRT is missing.
#>

# ---------- Logging ----------
$LogPath = "$env:ProgramData\HybridJoinCheck.log"
function Write-Log {
    param([string]$Message)
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    "$timestamp - $Message" | Out-File -FilePath $LogPath -Append -Encoding utf8
}

Write-Log "===== Starting Hybrid Join Check ====="


# ---------- Run dsregcmd /status ----------
$dsreg = dsregcmd /status

# Extract values
$AzureADJoined  = ($dsreg | Select-String "AzureAdJoined\s*:\s*YES") -ne $null
$DomainJoined   = ($dsreg | Select-String "DomainJoined\s*:\s*YES") -ne $null
$PRTActive      = ($dsreg | Select-String "AzureAdPrt\s*:\s*YES") -ne $null


Write-Log "AzureADJoined: $AzureADJoined"
Write-Log "DomainJoined: $DomainJoined"
Write-Log "AzureAdPRT: $PRTActive"


# ---------- Determine Hybrid Join Health ----------
$HybridHealthy = ($AzureADJoined -and $DomainJoined -and $PRTActive)

if ($HybridHealthy) {
    Write-Log "Hybrid Join and PRT are healthy. No action required."
    exit 0
}

Write-Log "Hybrid Join or PRT is NOT healthy — Performing WAM reset."


# ---------- Perform WAM Reset ----------
$UserProfile = $env:LOCALAPPDATA

$PathsToClear = @(
    "$UserProfile\Microsoft\IdentityCache",
    "$UserProfile\Microsoft\TokenBroker",
    "$UserProfile\Microsoft\OneAuth"
)

foreach ($Path in $PathsToClear) {
    try {
        if (Test-Path $Path) {
            Write-Log "Deleting: $Path"
            Remove-Item $Path -Recurse -Force -ErrorAction Stop
        } else {
            Write-Log "Path not found (skipped): $Path"
        }
    }
    catch {
        Write-Log "ERROR deleting $Path : $_"
    }
}

Write-Log "WAM reset complete. Forcing re-registration and token renewal."

# Optional: silently trigger re-registration
Start-Process "dsregcmd.exe" -ArgumentList "/leave" -WindowStyle Hidden
Start-Sleep -Seconds 2
Start-Process "dsregcmd.exe" -ArgumentList "/join" -WindowStyle Hidden

Write-Log "===== Completed Hybrid Join Check ====="
exit 0