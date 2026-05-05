Function Exists-NewStudentUser
{
    param
    (
        [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [String]$Username
        )

        try{
        [Bool] $Exists = $False
            $Exists = (Get-ADUser -Identity $Username)
        }
        catch{}

        return $Exists
}

Exists-NewStudentUser -Username "BALLDA"