Param 
(
    [Parameter (Mandatory=$true,ValueFromPipelineByPropertyName=$true)]  
    [String]$StudentUser,
    [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
    [String]$Group
)

$Path = "\\Gondor\Students$\"
$user = Get-ADUser $StudentUser -Properties Description
$description = $user.description.Split(" ")
$i = $description.Count - 1
$oldgroup = $description[$i]
$oldPath = "$Path$oldgroup\$StudentUser"
$NewPath = "$Path$group"
Write-Host -ForegroundColor Cyan "Moving Student folder $oldPath to $NewPath"
Move-Item -Path $oldPath -Destination $NewPath -Confirm:$false -Force
Write-Host -ForegroundColor Cyan "Removing $StudentUser from $oldgroup"
Remove-ADGroupMember -Identity $oldgroup -Members $StudentUser -Confirm:$false
Write-Host -ForegroundColor Cyan "Adding $StudentUser to $Group"
Add-ADGroupMember $Group -Members $StudentUser
If($oldgroup -eq "AWD7") {
        Write-Host -ForegroundColor Green "Removing $StudentUser.admin account"
        Remove-ADUser "$($StudentUser).admin" -Confirm:$false
}