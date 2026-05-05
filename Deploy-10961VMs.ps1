param(
$ServerPrefix = "A116"
)

1..21 |% {
    if($_ -lt 10){
        $server = "$ServerPrefix-0$_-SVR"
    }
    else {
        $server = "$ServerPrefix-$_-SVR"
    };
    Start-Job -ArgumentList $server {
        param($s) 
            copy "D:\Lab_Images\MOC\10961" "\\$s\d$\Program Files\Microsoft Learning" -Recurse;
            Invoke-Command -ComputerName $s -FilePath "D:\Lab_Images\MOC\10961\Drives\CreateVirtualSwitches.ps1";
            Invoke-Command -ComputerName $s -FilePath "D:\Lab_Images\MOC\10961\Drives\VM-Pre-Import-10961C.ps1";
            Invoke-Command -ComputerName $s -FilePath "D:\Lab_Images\MOC\10961\Drives\10961C_ImportVirtualMachines.ps1";
            Stop-Computer $s;
            "$s Complete" >> out.txt
        }
    }