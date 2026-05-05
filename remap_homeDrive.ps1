#Get based on AD group 'Students'
$users = Get-ADGroup "StaffAdmins" | Get-ADGroupMember -Recursive | Get-ADUser -Properties HomeDirectory, Description

#Update HomeDirectories
$users | ? HomeDirectory -like "\\frodo*" | % { $_ | Set-ADUser -HomeDirectory ($_.HomeDirectory=("\\gondor\"+$_.HomeDirectory.Substring(8))) } 

echo "Skipping:"
$users | ? HomeDirectory -notlike "\\frodo*" | select name, HomeDirectory

#Check ACL
#$dom = (Get-ADDomain).NetBIOSName

#foreach($user in $users){
#	$acl = ((Get-ACL $user.HomeDirectory).Access | ? { $_.IdentityReference.Value -like ($dom + "\" + $user.SamAccountName) })##
	#if(! ($acl.FileSystemRights -eq "FullControl" -and $acl.AccessControlType -eq "Allow") ){
	#	echo ($user.SamAccountName + " ACL is incorrect")
#}
#}

#Get all the lab computers (under OU 'Labs', begging with A*)
#$comps = (Get-ADComputer -SearchBase (Get-ADOrganizationalUnit -Filter "Name -like 'Labs'") -Filter "name -like 'A*'").name

#invoke a gpupdate
#Invoke-Command $comps { gpupdate /force } -ErrorAction SilentlyContinue #This will take awhile to timeout against all the computers that aren't on
#[System.IO.Directory]::Exists("\\Frodo\Students$\Studio Grad")
#[ADSI]::Exists("LDAP://CN=Mark Buttsworth,OU=Staff,DC=TDM,DC=local")