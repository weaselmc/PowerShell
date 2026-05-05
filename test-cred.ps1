
[String]$Group = "BEG8"
[String]$AdminUser = "tdm\baraba"
$DomainCredential = [System.Management.Automation.PSCredential]::new($AdminUser, (Read-Host "Enter $AdminUser password" -AsSecureString))
[String]$vcadmin = "administrator@vsphere.local"
$VCcred = [System.Management.Automation.PSCredential]::new($vcadmin, (Read-Host "Enter $vcAdmin password" -AsSecureString))
[string]$RDPFilePath = "\\GONDOR\Students$"


if ((Get-Module VMware.PowerCLI) -eq $null){
    Import-Module VMware.PowerCLI}
if($Global:DefaultVIServers.Count -eq 0){
    Connect-VIServer "vcenter.tdmadmin.local" -Credential $VCcred
    }

$users = Get-ADGroupMember $Group | select -ExpandProperty SamAccountName
foreach($user in $users){
    $Server = "MSSQL-$User"
    $Username = "TDM\$User"
    #while ([string]::IsNullOrEmpty($vmIP)) {$vmIP = (Get-VMGuest $Server).IPAddress[0]}
    #Invoke-Command -ComputerName $Server -Credential $DomainCredential  -Args $Username {param($username) Add-LocalGroupMember -Group Administrators -Member $Username}
    #create rdpfile
    #New-VIPermission -Entity $Server -Principal $Username -Role "VirtualMachineConsoleUser" -Propagate $true
    Write-Host "Creating $RDPFilePath\$Group\$User\$Server.rdp" -ForegroundColor Yellow 
    New-RDPFile -Server $Server -Path "$RDPFilePath\$Group\$User"
    #Move-ADObject "CN=$server,CN=Computers,DC=tdm,DC=local" -TargetPath "OU=StudentVMs,DC=tdm,DC=local" -Credential $DomainCredential
}