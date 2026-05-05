$Domain = Get-ADDomain
$Username = "BILLY"
try{
    $NU = Get-ADUser -Identity "$Username" -Properties Description -ErrorAction SilentlyContinue
    $NU.Description.Split(" ")[0]
}
Catch
{
    write-host -ForegroundColor DarkMagenta "Creating new user:$Username"
}
