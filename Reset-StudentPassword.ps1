    param
    (
        [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true)]  
        [string]$SamAccountName,
        [switch]$External=$false
    )

    Begin {

    }

    Process {
        $user
        try { $user = Get-ADUser $SamAccountName -Properties Description,ExtensionAttribute1,LastLogonDate,PasswordLastSet }
        catch {
            Write-Host -ForegroundColor Cyan "ACCOUNT: $SamAccountName does not exist"
            Exit
        }
        $Description = $user.description.split(" ")
        $i = $Description.Count - 1
        $Group = $Description[$i]
        $GroupName = (Get-ADGroup $Group -Properties Description).Description
        $StudentId = $Description[0]
        if($External){
            $Password = "Password1"
        }
        else
        {
            $Password = "S$StudentId!"
        }

        $now = Get-Date

        Write-Host -ForegroundColor Yellow "Do you know them or have you seen their student card and does match the following:"
        Write-Host -ForegroundColor Yellow -NoNewline "Student Id: "
        Write-Host -ForegroundColor Green "$($Description[0])" 
        Write-Host -ForegroundColor Yellow -NoNewline "Group: "
        Write-Host -ForegroundColor Green "$Group - $GroupName"
        Write-Host -ForegroundColor Yellow -NoNewline "Name: "
        Write-Host -ForegroundColor Green "$($user.Name)"
        Write-Host -ForegroundColor Yellow -NoNewline "Middle Name: "
        Write-Host -ForegroundColor Green "$($user.ExtensionAttribute1)"
        Write-Host -ForegroundColor Yellow -NoNewline "Last Logon: "
        $LLDDays = ([TimeSpan]::new((((Get-Date).Add(-($user.LastLogonDate))).Ticks))).Days
        if($LLDDays -eq 1){
            Write-Host -ForegroundColor Green "$LLDDays day ago"
        } else {
            Write-Host -ForegroundColor Green "$LLDDays days ago"
        }
        Write-Host -ForegroundColor Yellow -NoNewline "Password Last Set: "
        $PLSDays = ([TimeSpan]::new((((Get-Date).Add(-($user.PasswordLastSet))).Ticks))).Days
        if($PLSDays -eq 1){
            Write-Host -ForegroundColor Green "$PLSDays day ago"
        } else {
            Write-Host -ForegroundColor Green "$PLSDays days ago"
        }

        $response = Read-Host "yes/no"
        While ($response -ne "y" -and  $response -ne "yes" -and $response -ne "n" -and $response -ne "no")
        {
            $response = Read-Host "yes/no"
        }       
        $reset = $null
        if($response -eq "y" -or $response -eq "yes") {
            $reset = $true            
        }
        else {
            Write-Host -ForegroundColor Yellow "What is their Course ... Does it match?"
            $response = Read-Host "yes/no"
            While ($response -ne "y" -and  $response -ne "yes" -and $response -ne "n" -and $response -ne "no")
            {
                $response = Read-Host "yes/no"
            }
            if($response -eq "y" -or $response -eq "yes") {
                Write-Host -ForegroundColor Yellow "Did they register a Middle Name and is it correct?"
                $response = Read-Host "yes/no"
                While ($response -ne "y" -and  $response -ne "yes" -and $response -ne "n" -and $response -ne "no")
                {
                    $response = Read-Host "yes/no"
                }
                if($response -eq "y" -or $response -eq "yes") {
                    $reset = $true 
                }
                else {
                    $reset = $false
                }
            }
            else {
                $reset = $false
            }
        }

        if($reset) {
            Write-Host -ForegroundColor Yellow "Reseting $SamAccountName password to $Password"
            Set-ADAccountPassword $SamAccountName -NewPassword (ConvertTo-SecureString $Password -AsPlainText -Force) -Reset -Confirm:$false
            Set-ADUser $SamAccountName -ChangePasswordAtLogon $true
            Write-Host -ForegroundColor Yellow "Unlocking $SamAccountName"
            Unlock-ADAccount $SamAccountName -Confirm:$false
        }
        else {
            write-host -ForegroundColor Red "Take picture of person and tell them to wait"
        }
    }

    End {
        $user=$null
        $response = $null
    }
