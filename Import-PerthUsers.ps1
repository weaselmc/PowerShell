$users = Import-Csv D:\Scripts\Users\Perth.csv
$path = "OU=Perth,DC=TDM,DC=LOCAL"
$password = ConvertTo-SecureString "Password1" -AsPlainText -Force

$cred = [PSCredential]::new("tdm\buttsm.admin", (ConvertTo-SecureString "?L1sa123?" -AsPlainText -Force)) #Get-Credential "tdm\buttsm.admin"

$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://arwen/PowerShell/ -Authentication Kerberos -Credential $cred
Import-PSSession $Session

Foreach($user in $users){
    $DisplayName = "$($user.firstname) $($user.lastname)"
    $upn = "$($user.email)@tdm.local"
    $description = "$($user.email)@tafe.wa.edu.au"
    New-ADUser -Name $DisplayName -Path $path -DisplayName $DisplayName -Description $description -UserPrincipalName $upn -AccountPassword $password -Enabled $true -GivenName $user.firstname -Surname $user.lastname -SamAccountName $user.email 
    
    Enable-Mailbox $DisplayName
    Set-Mailbox $DisplayName -ForwardingSmtpAddress $description -DeliverToMailboxAndForward $true  
}

Get-User -OrganizationalUnit "Perth" | Get-Mailbox | ft DisplayName, EmailAddresses, ForwardingSMTPAddress > D:\scripts\Users\Perth.txt


