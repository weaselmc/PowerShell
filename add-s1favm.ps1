$students = Get-Content C:\Users\buttsm.admin\Desktop\Student.txt
$VlanId = 208
foreach($student in $students){
    New-DipS1VMs -User $student -VlanId $VlanId
    $VlanId++
    }
