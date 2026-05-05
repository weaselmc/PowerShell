$names = Get-StudentUser | select -Unique GivenName
$list = @()

foreach ($name in $names){
    $u = Get-ADUser -Properties Title -Filter "GivenName -eq '$($name.GivenName)'" # -and Title -ne 'Mr'"
    if($u.count -ne 1) {
        $count = $u.count }
    else {
        $count = 1 }
    $obj = New-Object PSObject -Property @{GivenName=$name.GivenName; Count=$count}
    $list += $obj
}

$list | sort Count -Descending