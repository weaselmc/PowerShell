Set-ADAccountPassword "Trainee" -NewPassword (ConvertTo-SecureString "Password1" -AsPlainText -Force)
Unlock-ADAccount "Trainee" -Confirm:$False
Write-Host -ForegroundColor Yellow "Trainee Account Unlocked and Password set to " -NoNewline
Write-Host -ForegroundColor Green "Password1"