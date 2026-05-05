$users = Get-ChildItem "E:\AWE6"
foreach ($u in $users){
    $SamUser = $u.Name
    $Server = (Get-ChildItem $u.Fullname -Filter "*MSSQ*")
    $Server = $Server.Name.Substring(0,$server.name.Length-4)
    Invoke-Command -ComputerName $Server -ArgumentList $SAMUser -ScriptBlock { 
        param($uname)

        Add-LocalGroupMember -Group "Administrators" -Member $uname

        }
    Write-Host "$SAMUser added to Admins on $Server" -ForegroundColor Yellow
}