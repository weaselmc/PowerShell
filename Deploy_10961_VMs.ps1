For ($i=10;$i -lt 21;$i++) {Invoke-Command -ComputerName "A143-$i-SVR" -ScriptBlock { mkdir "D:\Program Files\Microsoft Learning"}}
for ($i=10;$i -lt 21;$i++) {Start-Job -ArgumentList $i {param($i) copy "D:\Lab_Images\MOC\10961" "\\A143-$i-SVR\d$\Program Files\Microsoft Learning" -Recurse }}
for ($i=11;$i -lt 21;$i++) 
{ 
    Invoke-Command -ComputerName "A143-$i-SVR" -FilePath "D:\Lab_Images\MOC\10961\Drives\CreateVirtualSwitches.ps1"
    Invoke-Command -ComputerName "A143-$i-SVR" -FilePath "D:\Lab_Images\MOC\10961\Drives\VM-Pre-Import-10961C.ps1"
    Invoke-Command -ComputerName "A143-$i-SVR" -FilePath "D:\Lab_Images\MOC\10961\Drives\10961C_ImportVirtualMachines.ps1"
   }

   for ($i=1;$i -lt 10;$i++) {
    Stop-Computer "A143-0$i-SVR"
}
for ($i=10;$i -lt 21;$i++) {
    Stop-Computer "A143-$i-SVR"
}