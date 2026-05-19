        Import-Module ActiveDirectory
        $users =  Import-Csv 'C:\Users\mark.admin\Downloads\Music and Media.csv'                       
        foreach( $user in $users) {
            

        [String]$StudentId = $user.StudentId
        [String]$MiddleName= $user.MiddleName
        [String]$PreferredName= $user.PreferredName
        [String]$Title= $user.Title
        [String]$Group = $user.Group
            $ExternalStudent = [System.Convert]::ToBoolean($External)
            $Firstname=$User.Firstname.ToUpper()
            $Lastname=$User.Lastname.ToUpper()

            $pattern = '[^a-zA-Z]'

            $mFirstname=$Firstname -replace $pattern
            $mLastname=$Lastname -replace $pattern
            
            #If a user has a last name shorter than 5 characters, then the username will be modified to have more username characters
            $LastnameLength = $mLastname.Length

            if ($LastnameLength -lt 5)
            {
                if($Firstname.Length + $LastnameLength -lt 6)
                {
                    $FirstnameLength = $Firstname.Length
                    }
                else
                {
                    $FirstnameLength = 6 - ($LastNameLength)
                    }
            }
            else
            {
                $LastnameLength=5
                $FirstnameLength = 1
            }
        
            $Notunique = $true          
            $Domain = Get-ADDomain "tdm.local" #specify option
            $NU = $null            
            while ($Notunique -eq $true)
            {
                $Username = $mLastname.substring(0,$LastnameLength) + $mFirstname.substring(0,$FirstnameLength)
                try{
                    $NU = Get-ADUser -Identity "$Username" -Properties Description -ErrorAction SilentlyContinue
                    
                }
                Catch
                {
                    write-host -ForegroundColor Magenta "Creating new user:$Username"
                    #Generates a password for the user, using the Students ID number
                    if($ExternalStudent)
                    {
                        $s = "ExternalStudents"
                        $Password = ConvertTo-SecureString "Password1"  -AsPlainText -Force
                    }
                    Elseif($EPStudent) 
                    {
                        $s = "EPStudents"
                        $Password = ConvertTo-SecureString "Password1"  -AsPlainText -Force
                        if ($Group -notlike "EP-*"){
                            $Group = "EP-$Group"}
                    }
                    Elseif($NBStudent) 
                    {
                        $s = "NBStudents"
                        $Password = ConvertTo-SecureString "Password1"  -AsPlainText -Force
                        if ($Group -notlike "NB-*"){
                            $Group = "NB-$Group"}
                    }
                    Elseif($Group -like "E8*")
                    {
                        $s = "E8"
                        $Password = ConvertTo-SecureString "Password1"  -AsPlainText -Force                        
                    }
                    else
                    {
                        $Password = ConvertTo-SecureString "S$StudentID!"  -AsPlainText -Force
                        $s = "Students"
                    }
                    $sou = Get-ADOrganizationalUnit -Filter {Name -eq $s}
                    $Fullname = "$Firstname "
                    if(-not [string]::IsNullOrEmpty($PreferredName)) {$Fullname += "($PreferredName) "}
                    if(-not [string]::IsNullOrEmpty($MiddleName)) {$Fullname += "($MiddleName "}
                    $Fullname +="$Lastname")
                    $Description = $StudentID + " " + $Fullname + " " + $Group
                    if ([string]::IsNullOrEmpty($sou)){
                        New-ADOrganizationalUnit -Name $s -Path $Domain.DistinguishedName -ErrorAction SilentlyContinue
                        $sou = Get-ADOrganizationalUnit -Filter {Name -eq $s}}
                    Write-Host "$Fullname $Firstname $MiddleName $LastName $PreferredName"
                    New-ADUser -Name $Fullname -GivenName $Firstname -Surname $Lastname -Title $Title -DisplayName $Fullname -SamAccountName $Username -UserPrincipalName "$Username@$($Domain.DNSRoot)" -EmailAddress "$StudentId@tafe.wa.edu.au" -Path $sou.DistinguishedName -Description $Description -AccountPassword $Password -Enabled $True -ChangePasswordAtLogon $true -WhatIf
                    break;
                    $ADGroup = Get-ADGroup -Filter {Name -eq $Group}
                    if ([string]::IsNullOrEmpty($ADGroup))
                    {
                        $sg = Get-ADGroup -Filter {Name -eq $s}
                        if([string]::IsNullOrEmpty($sg)){
                            New-ADGroup -Name $s -SamAccountName $s -GroupCategory Security -GroupScope Global -DisplayName $s -Path "OU=$s,$($Domain.DistinguishedName)" -ErrorAction SilentlyContinue
                        }
                        $g = Get-ADGroup -Filter {Name -eq $Group}
                        if([string]::IsNullOrEmpty($g)){
                            New-ADGroup -Name $Group -SamAccountName $Group -GroupCategory Security -GroupScope Global -DisplayName $Group -Path "OU=$s,$($Domain.DistinguishedName)"
                        }
                        Add-ADGroupMember -Identity $s -Members $Group
                    }
                    Add-ADGroupMember -Identity $Group -Members $Username
                    Start-Sleep -Seconds 5
                    $tu = Get-ADUser $Username
                    While([string]::IsNullOrEmpty($tu))
                    {
                        $tu = Get-ADUser $Username
                    }
                    if (![string]::IsNullOrEmpty($Middlename)){Set-ADUser $Username -Add @{"ExtensionAttribute1"= $Middlename}}
                    $tu = $null
                    #Creats a home directory for the student on the $HomeDirPath share
                    #$ghdir = New-Item -ItemType Directory -Path $HomeDirPath -ErrorAction SilentlyContinue
                    $hdir = New-Item -ItemType Directory -Path $HomeDirPath\$Username -ErrorAction SilentlyContinue
                    $hdir = Get-Item -Path $HomeDirPath\$Username
                    $Principal = $Domain.NetBIOSName + "\" + $Username
                    $Right = "FullControl"
                    $Rule = New-Object System.Security.AccessControl.FileSystemAccessRule($Principal,$Right,"ContainerInherit, ObjectInherit", "None","Allow")
                    $ACL = Get-Acl $hdir.FullName
                    $ACL.SetAccessRule($Rule)
                    Set-Acl $hdir.FullName $ACL
                    if(($Group -eq 'AWD7') -or ($Group -eq 'AVX6') -or ($Group -eq 'AB51'))
                    {
                        #New-StudentAdmin -Firstname $Firstname -Lastname $Lastname -StudentId $StudentId -Group $Group -Username $Username
                    #    $vms = Get-ClusterResource | ? {($_.OwnerGroup -like "HD*") -and ($_.State -eq "Offline")}
                    #    $Server = $vms[0]
                    #    Start-ClusterResource $Server
                    #    start-sleep -Seconds 45
                    #    Add-StudentVMAccess -Username $Username -Group $Group  -Server $Server.OwnerGroup
                    }

                    if(($Group -eq 'BEH5') -or ($Group -eq 'BEG8'))
                    {
                        #$secpasswd = ConvertTo-SecureString ???  -AsPlainText -Force
                        #$DomainCred = New-Object System.Management.Automation.PSCredential ("TDM.LOCAL\buttsm.admin", $secpasswd)
                        
                        #Add-StudentSQLVMAccess -Username $Username -Group $Group
                        New-MSSQLVM -User $Username -Group $Group -DomainCredential $DomainCredential -VCcred $VCcred -ErrorAction Continue
                    }
                    if($Group -like 'E8*'){
                        Import-Module VMware.vSphere.SsoAdmin
                        if([String]::IsNullOrEmpty($global:DefaultSsoAdminServers)) {
                            Connect-SsoAdminServer -Server "vcenter.tdmadmin.local" -Credential $VCcred -SkipCertificateCheck
                        }
                        New-SsoPersonUser -UserName $Username -FirstName $FirstName -LastName $LastName -Password "Pa55w.rd1234" -ErrorAction Continue                     
                        New-E8vApp -User $Username -Group "E8" -VLan $Global:VLan -VCcred $VCcred
                    }
                    
                    #New-Item -ItemType Directory -Path "$HomeDirPath\$Username\Documents" -ErrorAction SilentlyContinue
                    #New-Item -ItemType Directory -Path "$HomeDirPath\$Username\Desktop" -ErrorAction SilentlyContinue
                    #New-Item -ItemType Directory -Path "$HomeDirPath\$Username\Downloads" -ErrorAction SilentlyContinue
                    #New-Item -ItemType Directory -Path "$HomeDirPath\$Username\Pictures" -ErrorAction SilentlyContinue
                    #New-Item -ItemType Directory -Path "$HomeDirPath\$Username\Music" -ErrorAction SilentlyContinue
                    #New-Item -ItemType Directory -Path "$HomeDirPath\$Username\Videos" -ErrorAction SilentlyContinue 
                    #New-Item -ItemType Directory -Path "$HomeDirPath\$Username\Favorites" -ErrorAction SilentlyContinue

                    Get-ADUser -Identity $Username | Set-ADUser -HomeDirectory "$HomeDirPath\$Username" -HomeDrive "U:"

                    "$Firstname,$Lastname,$Group,$StudentId,$Username" >> $Group-outfile.csv
                }
            
                if ([String]::IsNullOrEmpty($NU))
                    { $Notunique = $false }
                if ($Notunique -eq $true)
                {
                    $id = $NU.Description.Split(" ")[0]
                    if($StudentId -eq $id)
                    {
                        Write-Host -ForegroundColor Cyan "$Firstname $Lastname $StudentId ($($NU.SamaccountName)) already exists."
                        #Exit
                        break                   
                        }
                    else 
                    {                        
                        $NU = $null
                        $LastnameLength = $LastnameLength -1
                        $FirstnameLength = $FirstnameLength +1
                        #what happens if no characters are left?
                        }
                }
            }
            
            
        }  
