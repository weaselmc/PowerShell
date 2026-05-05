$SD = Get-ChildItem e:\ -Filter "A*"
foreach($d in $SD){
    $users = Get-ChildItem $d.FullName
    $Domain = Get-ADDomain
    $Right = "FullControl"
    Foreach($user in $users){
        $Principal = $Domain.NetBIOSName + "\" + $user.name
        $Rule = New-Object System.Security.AccessControl.FileSystemAccessRule($Principal,$Right,"ContainerInherit, ObjectInherit", "None","Allow")
        $ACL = Get-Acl $user.FullName
        $ACL.SetAccessRule($Rule)
        Set-Acl $user.FullName $ACL
        write-host -ForegroundColor Yellow $user.FullName
        
    }
}
