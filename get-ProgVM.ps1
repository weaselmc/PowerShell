$files = Get-ChildItem "V:\AWE6" -Recurse -Filter MSSQL*
foreach($file in $files){
    $server = ($file.name).substring(13)
    $len = ($file.directory).length
    $student = ($file.directory).substring(($len - 6), 6)
}