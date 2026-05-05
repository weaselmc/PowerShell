$AWE6 = Get-ChildItem v:\awe6\
$i = 2
foreach($user in $AWE6){
    if($i -le 9) {
        $Server = "MSSQLServer00$i"
        }
    else {
        $Server = "MSSQLServer0$i"
        }

    New-RDPFile -Server $Server -Path $user.FullName -Verbose
    $i++
}