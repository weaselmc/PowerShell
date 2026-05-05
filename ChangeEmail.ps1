$users = Get-ADUser -Filter * -SearchBase "OU=Students,DC=tdm,DC=local" -Properties Description
Foreach($u in $users){
    $d = $u.Description.Split(" ")
    write-host "$($d[0])@tafe.wa.edu.au" -ForegroundColor Green    
    Set-ADUser $u -EmailAddress "$($d[0])@tafe.wa.edu.au"
    }