$rooms = "A143", "A103", "A104", "A105", "A106", "A114", "A116", "A118", "A133", "A135", "A137"
$machines = $null
foreach ($room in $rooms) {
    $machines += 1..9 | % {"$room-0$_"}
    $machines += 10 .. 25| % {"$room-$_"}
}
$ErrorActionPreference = "SilentlyContinue"
foreach ($machine in $machines){
    if((Test-Connection $machine -Count 1 -Quiet) -eq $true){   
        Invoke-Command -ComputerName "$machine.tdm.local" {
        $AddedFolder ="C:\Program Files\Python310\Scripts"
        $OldPath=(Get-ItemProperty -Path ‘Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment’ -Name PATH).Path
        $NewPath=$OldPath+’;’+$AddedFolder
        Set-ItemProperty -Path ‘Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment’ -Name PATH –Value $newPath
        }    
        Write-Host "$machine done"     
    }
    else {
        Write-Host "$machine not done"
    }
}