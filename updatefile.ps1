$users = Get-ChildItem E:\AWE6
Foreach($user in $users){
    $file = Get-ChildItem $user.fullname
    $name = $file.Name
    if($name.Length -ne 12){
        $filename = $name.Split(" ")[2]
        $file.MoveTo("E:\AWE6\$($user.name)\$filename")
        }
}