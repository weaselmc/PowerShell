import-module activedirectory
$sp = Read-Host -Prompt "Enter MIM Password" -AsSecureString
New-ADUser –SamAccountName MIMINSTALL –name MIMINSTALL
Set-ADAccountPassword –identity MIMINSTALL –NewPassword $sp
Set-ADUser –identity MIMINSTALL –Enabled 1 –PasswordNeverExpires 1
New-ADUser –SamAccountName MIMMA –name MIMMA
Set-ADAccountPassword –identity MIMMA –NewPassword $sp
Set-ADUser –identity MIMMA –Enabled 1 –PasswordNeverExpires 1
New-ADUser –SamAccountName MIMSync –name MIMSync
Set-ADAccountPassword –identity MIMSync –NewPassword $sp
Set-ADUser –identity MIMSync –Enabled 1 –PasswordNeverExpires 1
New-ADUser –SamAccountName MIMService –name MIMService
Set-ADAccountPassword –identity MIMService –NewPassword $sp
Set-ADUser –identity MIMService –Enabled 1 –PasswordNeverExpires 1
New-ADUser –SamAccountName MIMSSPR –name MIMSSPR
Set-ADAccountPassword –identity MIMSSPR –NewPassword $sp
Set-ADUser –identity MIMSSPR –Enabled 1 –PasswordNeverExpires 1
New-ADUser –SamAccountName MIMpool –name MIMpool
Set-ADAccountPassword –identity MIMPool –NewPassword $sp
Set-ADUser –identity MIMPool –Enabled 1 -PasswordNeverExpires 1
New-ADGroup –name MIMSyncAdmins –GroupCategory Security –GroupScope Global –SamAccountName MIMSyncAdmins
New-ADGroup –name MIMSyncOperators –GroupCategory Security –GroupScope Global –SamAccountName MIMSyncOperators
New-ADGroup –name MIMSyncJoiners –GroupCategory Security –GroupScope Global –SamAccountName MIMSyncJoiners
New-ADGroup –name MIMSyncBrowse –GroupCategory Security –GroupScope Global –SamAccountName MIMSyncBrowse
New-ADGroup –name MIMSyncPasswordSet –GroupCategory Security –GroupScope Global –SamAccountName MIMSyncPasswordSet
Add-ADGroupMember -identity MIMSyncAdmins -Members Administrator
Add-ADGroupmember -identity MIMSyncAdmins -Members MIMService
Add-ADGroupmember -identity MIMSyncAdmins -Members MIMAdmin

setspn -S http/mim.tdm.local tdm\mimpool
setspn -S http/mim tdm\mimpool
setspn -S http/passwordreset.tdm.local tdm\mimsspr
setspn -S http/passwordregistration.tdm.local tdm\mimsspr
setspn -S FIMService/mim.tdm.local tdm\MIMService

#gSMA
New-ADUser –SamAccountName MIMAdmin –name MIMAdmin
Set-ADAccountPassword –identity MIMAdmin –NewPassword $sp
Set-ADUser –identity MIMAdmin –Enabled 1 –PasswordNeverExpires 1

New-ADUser –SamAccountName svcSharePoint –name svcSharePoint
Set-ADAccountPassword –identity svcSharePoint –NewPassword $sp
Set-ADUser –identity svcSharePoint –Enabled 1 –PasswordNeverExpires 1

New-ADUser –SamAccountName svcMIMSql –name svcMIMSql
Set-ADAccountPassword –identity svcMIMSql –NewPassword $sp
Set-ADUser –identity svcMIMSql –Enabled 1 –PasswordNeverExpires 1

New-ADUser –SamAccountName svcMIMAppPool –name svcMIMAppPool
Set-ADAccountPassword –identity svcMIMAppPool –NewPassword $sp
Set-ADUser –identity svcMIMAppPool –Enabled 1 -PasswordNeverExpires 1

setspn -S http/mim.tdm.local tdm\svcMIMAppPool

New-ADGroup –name MIMSync_Servers –GroupCategory Security –GroupScope Global –SamAccountName MIMSync_Servers
Add-ADGroupmember -identity MIMSync_Servers -Members Shelob$

New-ADServiceAccount -Name MIMSyncGMSAsvc -DNSHostName MIMSyncGMSAsvc.tdm.local -PrincipalsAllowedToRetrieveManagedPassword "MIMSync_Servers"

New-ADUser –SamAccountName svcMIMMA –name svcMIMMA
Set-ADAccountPassword –identity svcMIMMA –NewPassword $sp
Set-ADUser –identity svcMIMMA –Enabled 1 –PasswordNeverExpires 1

New-ADGroup –name MIMService_Servers –GroupCategory Security –GroupScope Global –SamAccountName MIMService_Servers
Add-ADGroupMember -identity MIMService_Servers -Members Shelob$

New-ADServiceAccount -Name MIMSrvGMSAsvc -DNSHostName MIMSrvGMSAsvc.tdm.local -PrincipalsAllowedToRetrieveManagedPassword "MIMService_Servers" -OtherAttributes @{'msDS-AllowedToDelegateTo'='FIMService/shelob.tdm.local'}

Set-ADServiceAccount -Identity MIMSrvGMSAsvc -TrustedForDelegation $true -ServicePrincipalNames @{Add="FIMService/shelob.tdm.local"}

Add-ADGroupmember -identity MIMSyncPasswordSet -Members MIMSrvGMSAsvc$ 
Add-ADGroupmember -identity MIMSyncBrowse -Members MIMSrvGMSAsvc$

