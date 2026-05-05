Param(           
    [String]$Group,
    [String]$User
    )

If([string]::IsNullOrEmpty($User) -and ![string]::IsNullOrEmpty($Group)) {
    $Users = Get-ADGroupMember $Group | ForEach-Object {Get-ADUser -Identity $_ -Properties HomeDirectory}
    Foreach ($U in $Users) {
        Remove-Item $U.HomeDirectory -Recurse -Force
        Remove-ADUser $U -Confirm:$false
    }
}
elseif(![string]::IsNullOrEmpty($User)){
    Remove-Item $User.HomeDirectory -Recurse
    Remove-ADUser $User
}
else {
    <# Action when all if and elseif conditions are false #>
    Write-Error "Need a User or Group."
}