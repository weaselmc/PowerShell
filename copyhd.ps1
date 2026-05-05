$users = Get-ADUser -Filter * -Properties HomeDirectory | ? HomeDirectory -like "\\Frodo\*"
foreach($user in $users){    
    Set-ADUser $user -HomeDirectory "\\Gondor\staff$\$($user.SamAccountName)"
    Copy-Item  "\\Frodo\Staff$\$($user.SamAccountName)" "\\Gondor\staff$\" -Recurse
}