$du = get-aduser -Filter * -SearchBase "OU=Students,DC=tdm,DC=local" -Properties Enabled | ? {$_.Enabled -eq $false}
$p = ConvertTo-SecureString "Password1" -AsPlainText -Force

foreach($u in $du){
    Set-ADAccountPassword $u -NewPassword $p
    Set-ADUser $u -PasswordNeverExpires $false -ChangePasswordAtLogon $true -Enabled $true
    }