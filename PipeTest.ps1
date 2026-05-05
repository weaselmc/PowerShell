Function New-StudentUserTest
{
    <#
    .SYNOPSIS
    Creates a student user account with home directory.

    .DESCRIPTION
    Creates student accounts in the current domain with home directories in the specified location. 
    Requires a Firstname, Lastname, ID and Group.

    .PARAMETER Firstname
    Student Firstname.


    .EXAMPLE
    New-StudentUser -Firstname John -Lastname Smith -Group AWE6 -StudentId J999000

    #>
    
    param
    (
        [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [string]$Firstname ,
        [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [String]$Lastname,
        [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [String]$StudentId,
        [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [String]$Group,
        [String]$Server,
        [Parameter (ValueFromPipelineByPropertyName=$true)]
        [Boolean]$External = $false,
        [String]$HomeDirPath = "\\frodo\students$")
        
        process{ 
        Import-Module ActiveDirectory
        write-host -ForegroundColor DarkCyan "$cargs"
        write-host -ForegroundColor Cyan "$Firstname"
        write-host -ForegroundColor yellow "$Lastname"
        write-host -ForegroundColor Green "$Group"
        write-host -ForegroundColor Magenta "$StudentId"
        }
        }

        import-csv .\AVZ2.csv | New-StudentUserTest