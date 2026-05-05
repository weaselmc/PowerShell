$Users = Get-ADGroupMember BEH5 | select -ExpandProperty SamAccountName
[String]$Group = "BEH5"
[string]$RDPFilePath = "\\GONDOR\Students$"
$DomainCredential = [System.Management.Automation.PSCredential]::new("tdm\baraba", (Read-Host "Enter password" -AsSecureString))

foreach ($User in $Users){
    $Server = "MSSQL-$User"
    $Username = "TDM\$User"
    $vmIP = $null
    
    while ([string]::IsNullOrEmpty($vmIP)) {$vmIP = (Get-VMGuest $Server).IPAddress[0]}
    Write-Host "Adding $Username to $Server on $vmIP" -ForegroundColor Yellow 
    Invoke-Command -ComputerName $Server -Credential $DomainCredential -Args $Username {param($username) Add-LocalGroupMember -Group Administrators -Member $Username}
    Write-Host "Creating $RDPFilePath\$Group\$User\$Server.rdp" -ForegroundColor Yellow 
    New-RDPFile -Server $Server -Username $User -Path "$RDPFilePath\$Group\$User"
    Move-ADObject "CN=$server,CN=Computers,DC=tdm,DC=local" -TargetPath "OU=StudentVMs,DC=tdm,DC=local"
}