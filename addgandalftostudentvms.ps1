
<# 
.Synopsis 
    Delegates control of OU to Connection Broker security group
    
.Description 
    Delegates control of OU to Connection Broker security group. It delegates the Connection Broker security group the following permissions
    1. Create Child
    2. Delete Child
    
    Note: this script should be run on AD machine as a AD domain admin.
    
.Example 
    PS C:\> Delegate-ControlToConnectionBroker.ps1
        
.Notes 
    Name     : Delegate-ControlToConnectionBroker.ps1  
#>

# print error message and exit
function Print-Error([System.String]$Msg)
{
	Write-Host $Msg
	Exit(1)
}

# delegate ou permissions to CB group
function DelegateControl([System.String]$OuDN, [System.Security.Principal.SecurityIdentifier]$CBGroupSid)
{
    $pathOU = "LDAP://" + $OuDN

    $OU=[adsi]$pathOU 

    $compGuid = new-object System.Guid -Arg "bf967a86-0de6-11d0-a285-00aa003049e2"
    $permissions = [System.DirectoryServices.ActiveDirectoryRights]::CreateChild -bor [System.DirectoryServices.ActiveDirectoryRights]::DeleteChild
    $AccessControlType = [System.Security.AccessControl.AccessControlType]::Allow
    $inheritance = [System.DirectoryServices.ActiveDirectorySecurityInheritance]::All
    $cbAccessRule1 = new-object System.DirectoryServices.ActiveDirectoryAccessRule -Arg $CBGroupSid, $permissions, $AccessControlType, $compGuid, $inheritance

    $permissions = [System.DirectoryServices.ActiveDirectoryRights]::GenericAll
    $inheritance = [System.DirectoryServices.ActiveDirectorySecurityInheritance]::Descendents
    $cbAccessRule2 = new-object System.DirectoryServices.ActiveDirectoryAccessRule -Arg $CBGroupSid, $permissions, $AccessControlType, $inheritance, $compGuid
    
    $OU.ObjectSecurity.AddAccessRule($cbAccessRule1)
    $OU.ObjectSecurity.AddAccessRule($cbAccessRule2)

    $OU.psbase.options.securitymasks=[System.DirectoryServices.Securitymasks]::Dacl

    $OU.CommitChanges()
}

# check if given OU exists
function IsOuExists([System.String]$OuDN)
{
    $Ou = Get-ADObject -Identity $OuDN
    if($Ou -eq $NULL) 
    {    
        return $False
    }
    return $True
}

# main routine
function main([System.String[]]$CBList, [System.String]$OuDN) 
{
    
    Import-Module ActiveDirectory -ErrorAction stop

    pushd AD:
    
    
    #check ou exists
    if(!(IsOuExists $OuDN))
    {
        Print-Error 'Specified OU does not exists. Please create it manually and then run this script.'
    }
    
    foreach($CBName in $CBList) 
    {
        $CBObject = Get-ADComputer $CBName -ErrorAction SilentlyContinue
        if($CBObject -ne $NULL) 
        {
            # delegate permissions
            DelegateControl $OuDN $CBObject.SID
            Write-Host "Delegation of control of OU $OuDN to Connection Broker $CBName succeeded"
        }else{
            Write-Error "Delegation of control of OU $OuDN to Connection Broker $CBName failed. AD object for Connection Broker was not found."
        }
        
    }
    
    popd
    exit(0)
}

$CBList = @("CN=GANDALF,CN=Computers,DC=tdm,DC=local")
$OuDN = "OU=StudentVMs,DC=tdm,DC=local"

main $CBList $OuDN

