    param(
    [string]$StudentId,
    [string]$FirstName,
    [string]$LastName,
    [string]$AccountName,
    [switch]$External=$false
    )
     
    
    if($External)
    {
        $sb = "OU=ExternalStudents,DC=TDM,DC=LOCAL"
    }
    else
    {
        $sb = "OU=Students,DC=TDM,DC=LOCAL"
    }
    if([string]::IsNullOrEmpty($AccountName)){
        Get-ADUser -Filter * -SearchBase $sb -Properties Description,lastlogondate,passwordlastset | ? { $_.Description -like "$StudentId*$FirstName*$LastName*" }  #-or $_.Description -Contains  -or $_.Description -Contains }
    }
    else {
        Get-ADUser $AccountName -Properties description,lastlogondate,passwordlastset | ? { $_.Description -like "$StudentId*$FirstName*$LastName*"  } # -or $_.Description -Contains $FirstName -or $_.Description -Contains $LastName}        
    }