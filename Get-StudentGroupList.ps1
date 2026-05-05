$groups = Get-ADGroup -SearchBase "OU=Students,DC=tdm,DC=local" -Filter *
foreach($group in $groups) {
    Get-ADGroupMember $group | Get-ADUser -Properties EmailAddress -ErrorAction SilentlyContinue | select Name,SamAccountName,EmailAddress,@{n="Group";e={$group.Name}} | Export-csv "\\gondor\admin\Student Lists\TDM\Complete\$($group.Name).csv"
}
