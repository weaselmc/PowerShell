$Lab = "HD"
$OU="OU=StudentVMs,dc=tdm,dc=local"
#New-ADOrganizationalUnit -Name $lab -Path $OU
For ($i=1; $i -le 9; $i++) {
    New-ADComputer -Name "$($Lab)00$i" -Path $OU
    #New-ADComputer -Name "$Lab-0$i-SVR" -Path "OU=$Lab,$OU"
    }
For ($i=10; $i -le 50; $i++) {
    New-ADComputer -Name "$($Lab)0$i" -Path $OU
    #New-ADComputer -Name "$Lab-$i-SVR" -Path "OU=$Lab,$OU"
    }