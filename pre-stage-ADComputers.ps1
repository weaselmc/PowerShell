$Lab = "A129"
$OU="OU=Labs,dc=tdm,dc=local"
#New-ADOrganizationalUnit -Name $lab -Path $OU
For ($i=1; $i -le 3; $i++) {
    $Computer = $Lab + "-0$i"
    New-ADComputer -Name $Computer  -Path "OU=$Lab,$OU"
    New-ADComputer -Name "$Computer-SVR" -Path "OU=$Lab,$OU"
    }
#For ($i=10; $i -le 25; $i++) {
#    $Computer = $Lab + "-$i"
#    New-ADComputer -Name $Computer -Path "OU=$Lab,$OU"
#    New-ADComputer -Name "$Computer-SVR" -Path "OU=$Lab,$OU"
#    }