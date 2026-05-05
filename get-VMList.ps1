$AWE6 = Get-ChildItem V:\AWE6
$AWF2 = Get-ChildItem V:\AWF2

Foreach($UserDir in $AWE6){
    Get-ChildItem "$($UserDir.FullName)\*.rdp" | Select FullName
}

Foreach($UserDir in $AWF2){
    Get-ChildItem "$($UserDir.FullName)\*.rdp" | Select FullName
}