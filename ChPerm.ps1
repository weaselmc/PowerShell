$dir = Get-ChildItem -Path E:\AWF2 -Directory 
foreach($d in $dir)
{
    $Principal = "TDM\" + $d.Name
    $Right = "FullControl"
    $Rule = New-Object System.Security.AccessControl.FileSystemAccessRule($Principal,$Right,"ContainerInherit, ObjectInherit", "None", "Allow")
    $ACL = Get-Acl $d.FullName
    $ACL.SetAccessRule($Rule)
    Set-Acl $d.FullName $ACL
}