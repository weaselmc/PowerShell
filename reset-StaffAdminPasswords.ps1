$staffadmins = Get-ADGroupMember "StaffAdmins" | Get-ADUser -Properties LastLogonDate, PasswordLastSet
$Password = Read-Host "Enter Password" -AsSecureString
$staffadmins | select name, PasswordLastSet, LastLogonDate, @{n="DaysAgo";e={[TimeSpan]::new((((Get-Date).Add(-($_.PasswordLastSet))).Ticks)).Days}}
Foreach($admin in $staffadmins){
    if([String]::IsNullOrEmpty($admin.LastLogonDate)){
        $response = "y"
    }
    else {
        $response = Read-Host "Reset $admin (y/n)?"
    }
    While ($response.ToLower() -ne "y" -and $response.ToLower() -ne "n" -and $response.ToLower() -ne "yes" -and $response.ToLower() -ne "no")
    {
        $response = Read-Host "Error: Reset $admin (y/n)?"
    }
    if($response.ToLower() -eq "y" -or $response.ToLower() -eq "yes"){
        Set-ADAccountPassword $admin.SamAccountName -NewPassword $Password -Reset -Confirm:$false
        Set-ADUser $SamAccountName -ChangePasswordAtLogon $true
        Unlock-ADAccount $admin.SamAccountName
    }
}