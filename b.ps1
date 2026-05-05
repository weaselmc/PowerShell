$users = Get-ADGroupMember AWF2
$l
foreach ($user in $users){
    $u = Get-ADUser $user -properties Description
    [student] $s = $($u.description).split(" ")
    $l += $s
}

Class Student
{
    [String]$Firstname
    [String]$Lastname
    [String]$StudentId
    [String]$Group
    [Boolean]$External
}