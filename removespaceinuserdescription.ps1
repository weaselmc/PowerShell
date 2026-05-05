$users = Get-ADUser -Filter * -SearchBase  "DC=TDM,DC=LOCAL"  -Properties HomeDirectory, Description | select Name,HomeDirectory,Description | ? { ($_.HomeDirectory -eq $null) -and ($_.Description -like "*Grad")}
foreach($user in $users){
    $d = $user.description.split(" ")
    $description = "$($d[0]) $($d[1]) $($d[2]) StudioGrad"
    $user | Set-ADUser -Description $description
}