$dir = Get-childItem C:\ClusterStorage\Volume1\StudentVMs -Directory
foreach($d in $dir)
{
    mkdir "C:\ClusterStorage\Volume3\$d" 
    $child = get-childitem $d.FullName -Directory
    foreach($c in $child)
    {
        mkdir "C:\ClusterStorage\Volume3\$d\$c" 
    }
}