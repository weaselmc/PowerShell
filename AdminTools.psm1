Function New-StudentUser
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
        [string]$FirstName ,
        [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [String]$LastName,
        [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [String]$StudentId,
        [Parameter (ValueFromPipelineByPropertyName=$true)]
        [String]$MiddleName="",
        [Parameter (ValueFromPipelineByPropertyName=$true)]
        [String]$PreferredName="",
        [Parameter (ValueFromPipelineByPropertyName=$true)]
        [String]$Title="",
        [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [String]$Group,
        [String]$Server,
        [Parameter (ValueFromPipelineByPropertyName=$true)]
        [bool]$External=$false,
        [bool]$EPStudent=$false,
        [bool]$NBStudent=$false,        
        #[Parameter(Mandatory)]
        [ValidateSet('Joondalup Campus', 'Perth Campus', 'East Perth Campus')]
        [string]$Location,
        [String]$HomeDirPath = "\\Gondor\students$" #,
        #[System.Management.Automation.PSCredential]$DomainCredential,
        #[System.Management.Automation.PSCredential]$VCcred
        )
        

        Begin
        {
             #$secpasswd = ConvertTo-SecureString ???  -AsPlainText -Force     
             #if([string]::IsNullOrEmpty($AdminUser)){ $AdminUser = Whoami.exe }
             #if([string]::IsNullOrEmpty($DomainCredential.UserName))
             #{
             #   $AdminUser = Whoami.exe 
             #   $DomainCredential = New-Object System.Management.Automation.PSCredential ($AdminUser, (Read-Host "Enter $AdminUser password" -AsSecureString))
             #}
             #if([string]::IsNullOrEmpty($VCcred.UserName))
             #{
             #   $VCAdminUser = "administrator@tdmadmin.vslocal" 
             #   $VCcred = New-Object System.Management.Automation.PSCredential ($VCAdminUser, (Read-Host "Enter $VCAdminUser password" -AsSecureString))
             #}

             Import-Module ActiveDirectory 
        }

        process{                       

            $ExternalStudent = [System.Convert]::ToBoolean($External)
            $Firstname=$Firstname.ToUpper()
            $Lastname=$Lastname.ToUpper()

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
                    if(-not [string]::IsNullOrEmpty($PreferredName)) {$Fullname += "[$PreferredName] "}
                    if(-not [string]::IsNullOrEmpty($MiddleName)) {$Fullname += "($MiddleName) "}
                    $Fullname +="$Lastname"
                    $Description = $StudentID + " " + $Fullname + " " + $Group
                    if ([string]::IsNullOrEmpty($sou)){
                        New-ADOrganizationalUnit -Name $s -Path $Domain.DistinguishedName -ErrorAction SilentlyContinue
                        $sou = Get-ADOrganizationalUnit -Filter {Name -eq $s}}
                    Write-Host -ForegroundColor DarkYellow "$Description"
                    New-ADUser -Name $Fullname -GivenName $Firstname -Surname $Lastname -Title $Title -DisplayName $Fullname -SamAccountName $Username -UserPrincipalName "$Username@$($Domain.DNSRoot)" -EmailAddress "$StudentId@tafe.wa.edu.au" -Path $sou.DistinguishedName -Description $Description -AccountPassword $Password -Enabled $True -ChangePasswordAtLogon $true -Verbose
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
                        Add-ADGroupMember -Identity $s -Members $Group -Verbose
                    }
                    Add-ADGroupMember -Identity $Group -Members $Username -Verbose
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
                    #    $vms = Get-ClusterResource | Where-Object {($_.OwnerGroup -like "HD*") -and ($_.State -eq "Offline")}
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
}

Function New-StudentAdmin
{
<#
    .SYNOPSIS
    Creates an admin student user account.

    .DESCRIPTION
    Creates an admin student account in the current domain adding it to the student admins group. 
    Requires a Firstname, Lastname, ID and Group.

    .PARAMETER Firstname
    Student Firstname.

    .PARAMETER Lastname
    Student Lastname.

    .PARAMETER StudentId
    Students Id string

    .PARAMETER Group
    Students Id string

    .PARAMETER Username
    Students username

    .EXAMPLE
    New-StudentAdmin -Firstname John -Lastname Smith -StudentId J999000 -Group AWD7 -Username SmithJ

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
        [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [String]$Username
        )

        $admin= $Username + ".admin"
        $Domain = Get-ADDomain
        $DNSSuffix = "markonetechnologies.com.au"
        $Fullname = "$Firstname $Lastname"
        $Description = "$StudentId $Fullname $Group Admin Account"
        $Password = "S$StudentID!" | ConvertTo-SecureString -AsPlainText -Force

        New-ADUser -Name "$Fullname Admin"-GivenName $Firstname -Surname $Lastname -DisplayName "$Fullname Admin" -SamAccountName $admin -UserPrincipalName "$admin@$DNSSuffix" -Path "OU=StudentAdmins,$($Domain.DistinguishedName)" -Description "$Description" -AccountPassword $Password -Enabled $True -ChangePasswordAtLogon $true
        Add-ADGroupMember -Identity "$Group-Admins" -Members $admin
        Write-Host -ForegroundColor Green "$admin account created."
}

Function New-HVMSSQLVM{
<#
.SYNOPSIS
Creates an MSSQLServer for the Programming Classes

.DESCRIPTION
Creates a VM with MSSSQL Server and Admin tools in a cluster. Adds remote desktop access. Can have IIS added to support REST or WCF server apps.

.PARAMETER Server
Server name for VM.

.PARAMETER User
User for RDP file creation.

.PARAMETER Group
Group user is in for RDP file creation

.PARAMETER

.EXAMPLE
New-MSSQLVM -Server ServerName -User "TDM.LOCAL\Student"

#>
    Param(           
        [Parameter (Mandatory=$true)]
        [String]$User,
        [String]$Group = "AWE6",
        [System.Management.Automation.PSCredential] $DomainCredential = (Get-Credential "TDM.LOCAL\buttsm.admin")
        )

    $VMHost = "Bilbo"
    $VMPath = "C:\ClusterStorage\Volume3" #"\\$VMHost\C$\ClusterStorage\Volume3"    
    $PPath = "C:\ClusterStorage\Volume7\VHDs\windowsserver2016gui_with_sqlaw_18.1.vhdx" #"\\$VMHost\C$\ClusterStorage\Volume7\VHDs\windowsserver2016gui_with_sqlaw_18.1.vhdx"
    $FSPath = "\\Gondor\students$"
    $Server = "MSSQL-$User"
    $VMServerPath = "$VMPath\$Server"

    $secpasswd = ConvertTo-SecureString "Pa55w.rd" -AsPlainText -Force
    $Cred = New-Object System.Management.Automation.PSCredential ("Administrator", $secpasswd)

    #if([string]::IsNullOrEmpty($DomainCredential)) {
    #    $DomainCred = Get-Credential "TDM.LOCAL\buttsm.admin"
    #}

    Write-Host -ForegroundColor Green "Importing from $VMServerPath"
    #Create new VM and add VHD's
    New-VHD "$VMServerPath\Virtual Hard Disks\$Server.vhdx" -Differencing -ParentPath $PPath
    New-VM -Name $Server -Path $VMPath -MemoryStartupBytes 8GB  -VHDPath "$VMServerPath\Virtual Hard Disks\$Server.vhdx" -Generation 2 -SwitchName "TDM Virtual Switch" -ComputerName $VMHost
    #$vm = Import-VM -Path (Get-ChildItem "$VMServerPath\Virtual Machines" -Filter *.vmcx).FullName -Copy -GenerateNewId -SmartPagingFilePath "$VMServerPath\Virtual Machines" -SnapshotFilePath "$VMServerPath\Snapshots" -VhdDestinationPath "$VMServerPath\Virtual Hard Disks" -VirtualMachinePath "$VMServerPath\Virtual Machines"
    $vm = Get-VM $Server
    $vm | Set-VM -MemoryMaximumBytes 16GB -ProcessorCount 2 -DynamicMemory
    $vmn = Get-VMNetworkAdapter -VMName $Server
    Set-VMNetworkAdapterVlan $vmn -VlanId 10 -Access
        
    Add-VMToCluster -VMName $vm.Name
    (Get-ClusterGroup $vm.Name).Priority = 1000
    Start-VM $vm
    #Get-ClusterResource $vm.Name
    Write-Host -ForegroundColor Yellow "Starting vm " -NoNewline
    $vmIP = $null
    While([string]::IsNullOrEmpty($vmIP))
    {
        try
        {
            $vmn = Get-VMNetworkAdapter $vm -ErrorAction Stop  
            $vmIP = $vmn.IPAddresses[0]
        } 
        catch
        { 
            Write-Host -ForegroundColor Yellow "." -NoNewline
            Start-Sleep -Seconds 5
        }        
    }
    #Read-Host "Set Administrator password before pressing enter!"
    Write-Host -ForegroundColor Yellow " Completed ($vmIP)"
    Invoke-Command -VMName $Server -Credential $Cred -ArgumentList $Server -ScriptBlock {
        Param($server)
        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server'-name "fDenyTSConnections" -Value 0
        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -name "UserAuthentication" -Value 0
        Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
        Get-NetFirewallRule -DisplayName "File and Printer Sharing*Echo*" | Enable-NetFirewallRule
        Remove-Item "C:\unattend.xml"
        Rename-Computer $Server
        }    
    Write-Host -ForegroundColor Yellow "Restarting vm " -NoNewline
    #New-ADComputer -Name $Server -Path "OU=StudentVMs,DC=TDM,DC=LOCAL" -Confirm:$false
    try {Restart-VM $vm -Force}
    catch{Start-VM $vm }
    Start-Sleep -Seconds 5    
    $vmIP = $null
    While([string]::IsNullOrEmpty($vmIP))
    {
        try
        {
            $vmn = Get-VMNetworkAdapter $vm -ErrorAction Stop  
            $vmIP = $vmn.IPAddresses[0]
        } 
        catch
        { 
            Write-Host -ForegroundColor Yellow "." -NoNewline
            Start-Sleep -Seconds 5
        }        
    }
    Write-Host -ForegroundColor Yellow " Completed ($vmIP)"
    Invoke-Command -VMName $Server -Credential $Cred -ArgumentList $DomainCred -ScriptBlock {
        Param($dc)

        Add-Computer -DomainName "tdm.local" -Credential $dc -OUPath "OU=StudentVMs,DC=TDM,DC=LOCAL"
    }
    Write-Host -ForegroundColor Yellow "Restarting vm " -NoNewline
    Stop-VM $vm -Force
    Start-Sleep -Seconds 5
    Start-VM $vm    
    $vmIP = $null
    While([string]::IsNullOrEmpty($vmIP))
    {
        try
        {
            $vmn = Get-VMNetworkAdapter $vm -ErrorAction Stop  
            $vmIP = $vmn.IPAddresses[0]
        } 
        catch
        { 
            Write-Host -ForegroundColor Yellow "." -NoNewline
            Start-Sleep -Seconds 5
        }        
    }
    Write-Host -ForegroundColor Yellow " Completed ($vmIP)"

    Invoke-Command -VMName $Server -Credential $DomainCred -ArgumentList $User -ScriptBlock { 
    param($uname)                
        Add-LocalGroupMember -Group "Administrators" -Member $uname
        }
    Checkpoint-VM $Server -SnapshotName "Starting Image"
    #Stop-VM -VMName $Server
    Move-ClusterVirtualMachineRole -Name $Server -MigrationType Live
    #Start-VM -ComputerName "Merry" -Name $Server
    New-RDPFile -Server $Server -Path "$FSPath\$Group\$User"
    Write-Host -ForegroundColor Green "$Server RDP created for $FSPath\$Group\$User" 
}

Function Get-ServerNames{
    Param(
        [Parameter (Mandatory=$true)]
        [string]$Prefix,
        [Parameter (Mandatory=$true)]
        [int]$NumberofServers
        )
    
    $out=@()
    $vmpath = Get-ChildItem C:\ClusterStorage\Volume3 | Select-Object -Last 1
    
    if([string]::IsNullOrEmpty($vmpath)){        
        for($i =1; $i -le $NumberofServers; $i++){
            $out += "$($Prefix)00$i"
        }
    }
    else {
        $LastVM = $vmpath.Name
        $NextVMNum = [int]$LastVM.Substring($LastVM.Length-3) + 1         
        for($i = $NextVMNum; $i -le $NumberofServers + $NextVMNum - 1; $i++){
            if($i -le 9){
                $out += "$($Prefix)00$i"
            }
            elseif($i -le 99){
                $out += "$($Prefix)0$i"
            }
            else {
                $out += "$($Prefix)$i"
            }
        }
    }

    return $out    
}

Function New-RDPFile{
<#
.SYNOPSIS
Creates RDP File connecting to a Server saved and a location.

.DESCRIPTION
Creates student accounts in the current domain with home directories in the specified location. 
Requires a Firstname, Lastname, ID and Group.

.PARAMETER Server
Student Server.

.PARAMETER Username
Student Username.


.PARAMETER Path
Student Path.

.PARAMETER IP
Student Server IP. Used if Server name is not registered in TDM DNS.


.EXAMPLE
New-RDPFile -Server $server -Username $username -Path C:\RDPFiles -IP 172.20.20.1

#>
    Param(
        [Parameter (Mandatory=$true)]
        [string]$Server,
        [string]$Username,
        [String]$Path,
        [String]$IP)
        
        $rdpstring = @"
screen mode id:i:2
use multimon:i:0
desktopwidth:i:2560
desktopheight:i:1440
session bpp:i:32
winposstr:s:0,1,0,0,800,600
compression:i:1
keyboardhook:i:2
audiocapturemode:i:0
videoplaybackmode:i:1
connection type:i:7
networkautodetect:i:1
bandwidthautodetect:i:1
displayconnectionbar:i:1
enableworkspacereconnect:i:0
disable wallpaper:i:0
allow font smoothing:i:0
allow desktop composition:i:0
disable full window drag:i:1
disable menu anims:i:1
disable themes:i:0
disable cursor setting:i:0
bitmapcachepersistenable:i:1
audiomode:i:0
redirectprinters:i:1
redirectcomports:i:0
redirectsmartcards:i:1
redirectclipboard:i:1
redirectposdevices:i:0
autoreconnection enabled:i:1
authentication level:i:2
prompt for credentials:i:0
negotiate security layer:i:1
remoteapplicationmode:i:0
alternate shell:s:
shell working directory:s:
gatewayhostname:s:
gatewayusagemethod:i:4
gatewaycredentialssource:i:4
gatewayprofileusagemethod:i:0
promptcredentialonce:i:0
gatewaybrokeringtype:i:0
use redirection server name:i:0
rdgiskdcproxy:i:0
kdcproxyname:s:
drivestoredirect:s:

"@
    if(-not [String]::IsNullOrEmpty($Username)) {$rdpstring += "username:s:$Username`r`n" }
    #full address:s:NWSQLServer003
    if([String]::IsNullOrEmpty($IP)){
        $rdpstring +=  "full address:s:$Server`r`n"
        }
    else {
        $rdpstring +=  "full address:s:$IP`r`n"
        }
    $rdpstring | Out-File -FilePath "$Path\$Server.rdp"        
}

Function Add-StudentVMAccess{
 Param(
        [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [string]$Username,
        [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [string]$Group,
        [Parameter (ValueFromPipelineByPropertyName=$true)]
        [string]$Server, 
        [Parameter (ValueFromPipelineByPropertyName=$true)]
        [string] $ServerPrefix)

    $Domain = Get-ADDomain
    if(([String]::IsNullOrEmpty($Server)) -and (![String]::IsNullOrEmpty($ServerPrefix)))
    {
        $Server = "$ServerPrefix*"}

    if([String]::IsNullOrEmpty($Server)){
        $cr = Get-ClusterResource | Where-Object {($_.OwnerGroup -like $Server) -and ($_.State -eq "Offline")}
        $Server = $cr[0]
        $SAMUser =   "$($Domain.NetBIOSName)\$Username"
        Start-ClusterResource $Server
        start-sleep -Seconds 30
        Invoke-Command -ComputerName $Server.OwnerGroup -ArgumentList $SAMUser -ScriptBlock { 
            param($uname)

            Add-LocalGroupMember -Group "Remote Desktop Users" -Member $uname
            Add-LocalGroupMember -Group "Administrators" -Member $uname
            Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server'-name "fDenyTSConnections" -Value 0
            Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -name "UserAuthentication" -Value 0
            Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
            }
        "$Username, $($Server.OwnerGroup)" | out-file -FilePath "\completed\VMs_$Group.csv" -Append
        New-RDPFile -Server $Server.OwnerGroup -Path "\\Frodo\Students$\$Group\$Username" -ErrorAction SilentlyContinue
        Write-host -ForegroundColor Yellow "Created \\Frodo\Students$\$Group\$Username\$($Server.OwnerGroup).rdp"
    }
    else {
        Write-host -ForegroundColor Yellow "No Server information provided."
    }
}
Function Get-NextVMNum{
    Param(
    [string]$ServerPrefix
    )
    $vms = Get-ClusterResource | Where-Object {($_.OwnerGroup -like "$ServerPrefix*")}
    if([string]::IsNullOrEmpty($vms))
    {
        $i = 1
    }
    else
    {
        $LastVM = $vms[$vms.Length-1].OwnerGroup.Name
        $i = [int]$LastVM.Substring($LastVM.Length-3) + 1
    }
    return $i
}


Function New-MSSQLVM{
<#
.SYNOPSIS
Creates an MSSQLServer for the Programming Classes

.DESCRIPTION
Creates a VM with MSSSQL Server and Admin tools in a cluster. Adds remote desktop access. Can have IIS added to support REST or WCF server apps.

.PARAMETER Server
Server name for VM.

.PARAMETER User
User for RDP file creation.

.PARAMETER Group
Group user is in for RDP file creation

.PARAMETER

.EXAMPLE
New-MSSQLVM -User Student

#>
    Param(           
        [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true, ValueFromPipeline=$true)]
        [String]$User,
        [String]$Group = "BEH5",
        #[String]$AdminUser = "TDM.LOCAL\baraba",
        [System.Management.Automation.PSCredential]$DomainCredential,
        #[String]$vcadmin = "administrator@tdmadmin.vslocal",
        [System.Management.Automation.PSCredential]$VCcred,
        [string]$RDPFilePath = "\\GONDOR.tdm.local\Students$"
        )

        Begin{
             #$secpasswd = ConvertTo-SecureString ???  -AsPlainText -Force 
             if([string]::IsNullOrEmpty($DomainCredential)){
                $AdminUser=whoami
                $DomainCredential = [System.Management.Automation.PSCredential]::new($AdminUser, (Read-Host "Enter $AdminUser password" -AsSecureString))
                }
             if([string]::IsNullOrEmpty($VCcred)){
                $vcadmin=whoami
                $VCcred =[System.Management.Automation.PSCredential]::new($vcadmin, (Read-Host "Enter $vcAdmin password" -AsSecureString))             
                }
            if ($null -eq (Get-Module VMware.PowerCLI)){
                Import-Module VMware.PowerCLI}
            if($Global:DefaultVIServers.Count -eq 0){
                Connect-VIServer "vcenter.tdmadmin.local" -Credential $VCcred
                }
        }
        process{   

            $Server = "MSSQL-$User"
            $Username = "TDM.LOCAL\$User"

            try { 
                Get-VM $Server -ErrorAction Stop
                write-host -ForegroundColor Green "Server $server already exists."                   
            } 
            catch {
                Write-Host "Creating $Server" -ForegroundColor Yellow
                New-VM -Template Base-Win2019_SQL -Name $Server -Datastore Prog_Datastore -Location Programming -OSCustomizationSpec WinServer2019TDMBase -ResourcePool Resources                    
                Start-VM $Server
                while ([string]::IsNullOrEmpty($vmIP)) {$vmIP = Get-VMGuest $Server | Select-Object -ExpandProperty IPAddress | Where-Object {$_ -like "172.20.*"}}
                Invoke-Command -ComputerName "$Server.tdm.local" -Credential $DomainCredential  -Args $Username {param($username) Add-LocalGroupMember -Group Administrators -Member $Username}
                #create rdpfile
                New-VIPermission -Entity $Server -Principal $Username -Role "VirtualMachineConsoleUser" -Propagate $true
                Write-Host "Creating $RDPFilePath\$Group\$User\$Server.rdp" -ForegroundColor Yellow 
                New-RDPFile -Server $Server -Username $User -Path "$RDPFilePath\$Group\$User"
                Move-ADObject "CN=$server,CN=Computers,DC=tdm,DC=local" -TargetPath "OU=StudentVMs,DC=tdm,DC=local" -Credential $DomainCredential
                $vmIP = $null
            }
        }
}

Function New-20744VM{
<#
.SYNOPSIS
Creates a 20744 Vertial Machine

.DESCRIPTION
Creates a VM with all the VM's for course 20744 nested in a single host.


.PARAMETER User
User for RDP file creation.

.PARAMETER Group
Group user is in for RDP file creation. Default is AB51 (Adv Dip Net Sec Cyber)

.PARAMETER

.EXAMPLE
New-20744VM -User Student

#>
    Param(           
        [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true, ValueFromPipeline=$true)]
        [String]$User,
        [String]$Group = "AB51",
        #[String]$AdminUser = "TDM.LOCAL\baraba",
        #[String]$vcadmin = "administrator@tdmadmin.vslocal",
        [PSCredential]$VCcred,
        [string]$RDPFilePath = "\\GONDOR.TDM.LOCAL\Students$"
        )

        Begin{
             #$secpasswd = ConvertTo-SecureString ???  -AsPlainText -Force             
             #$DomainCredential = New-Object System.Management.Automation.PSCredential ($AdminUser, (Read-Host "Enter $AdminUser password" -AsSecureString))
             if ($null -eq $VCcred){
                $vcadmin=whoami
                $VCcred = [System.Management.Automation.PSCredential]::new($vcadmin, (Read-Host "Enter $vcadmin password" -AsSecureString))
             }
                          
        }
        process{
           

            if ($null -eq (Get-Module VMware.PowerCLI)){
                Import-Module VMware.PowerCLI
            }

            if ($global:DefaultVIServers.count -eq 0){
                Connect-VIServer "vcenter.tdmadmin.local" -Credential $VCcred
            }
            
            $Server = "$User-20744C-LON-HOST1"
            $Username = "TDM.LOCAL\$User"

            try { 
                Get-VM $Server -ErrorAction Stop
                write-host -ForegroundColor Green "Server $server already exists."                    
            } 
            catch {
                Write-Host "Creating $Server" -ForegroundColor Yellow
                New-VM -Template 20744C-LON-HOST1 -Name $Server -Datastore Net_Datastore -Location Networking -ResourcePool Resources                   
                Start-VM $Server
                $vmIP = $null
                while ([string]::IsNullOrEmpty($vmIP)) {$vmIP = Get-VMGuest $Server | Select-Object -ExpandProperty IPAddress | Where-Object {$_ -like "172.20.*"}}
                #create rdpfile
                New-VIPermission -Entity $Server -Principal $Username -Role "VirtualMachineConsoleUser" -Propagate $true
                Write-Host "Creating $RDPFilePath\$Group\$User\$Server.rdp" -ForegroundColor Yellow 
                New-RDPFile -Server $Server -Path "$RDPFilePath\$Group\$User" -IP $vmIP                    
            }           
         
        }
}

Function New-20745VM{
<#
.SYNOPSIS
Creates a 20745 Host1 Vertial Machine

.DESCRIPTION
Creates a VM with all the VM's for course 20744 nested in a single host.


.PARAMETER User
User for RDP file creation.

.PARAMETER Group
Group user is in for RDP file creation. Default is AB51 (Adv Dip Net Sec Cyber)

.PARAMETER

.EXAMPLE
New-20744VM -User Student

#>
    Param(           
        [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true, ValueFromPipeline=$true)]
        [String]$User,
        [String]$Group = "BEH6",
        #[String]$AdminUser = "TDM.LOCAL\baraba",
        #[String]$vcadmin = "administrator@tdmadmin.vslocal",
        [PSCredential]$VCcred,
        [string]$RDPFilePath = "\\GONDOR.TDM.LOCAL\Students$"
        )

        Begin{
             #$secpasswd = ConvertTo-SecureString ???  -AsPlainText -Force             
             #$DomainCredential = New-Object System.Management.Automation.PSCredential ($AdminUser, (Read-Host "Enter $AdminUser password" -AsSecureString))
             if ($null -eq $VCcred){
                $vcadmin=whoami
                $VCcred = [System.Management.Automation.PSCredential]::new($vcadmin, (Read-Host "Enter $vcadmin password" -AsSecureString))
             }
                          
        }
        process{
           

            if ($null -eq (Get-Module VMware.PowerCLI)){
                Import-Module VMware.PowerCLI
            }

            if ($global:DefaultVIServers.count -eq 0){
                Connect-VIServer "vcenter.tdmadmin.local" -Credential $VCcred
            }
            
            $Server = "$User-20745B-LON-HOST1"
            $Username = "TDM.LOCAL\$User"

            try { 
                $vm = get-vm $Server -ErrorAction Stop
                write-host -ForegroundColor Green "Server $server already exists."                    
            } 
            catch {
                Write-Host "Creating $Server" -ForegroundColor Yellow
                $vm = New-VM -Template 20745-LON-HOST1 -Name $Server -Datastore Net_Datastore -Location NetDipStage2 -ResourcePool Resources -RunAsync
                while($vm.state -eq "Running")
                {
                    Start-Sleep 5
                    $vm = Get-Task -ID $vm.id
                }
                Start-VM $Server
                $vmIP = $null
                while ([string]::IsNullOrEmpty($vmIP)) {$vmIP = Get-VMGuest $Server | Select-Object -ExpandProperty IPAddress | Where-Object {$_ -like "172.20.*"}}
                #create rdpfile
                New-VIPermission -Entity $Server -Principal $Username -Role "VirtualMachineConsoleUser" -Propagate $true
                Write-Host "Creating $RDPFilePath\$Group\$User\$Server.rdp" -ForegroundColor Yellow 
                New-RDPFile -Server $Server -Path "$RDPFilePath\$Group\$User" -IP $vmIP                    
            }           
         
        }
}

Function New-20742VM{
<#
.SYNOPSIS
Creates a 20742 Host1 Vertial Machine

.DESCRIPTION
Creates a VM with all the VM's for course 20744 nested in a single host.


.PARAMETER User
User for RDP file creation.

.PARAMETER Group
Group user is in for RDP file creation. Default is AB51 (Adv Dip Net Sec Cyber)

.PARAMETER

.EXAMPLE
New-20744VM -User Student

#>
    Param(           
        [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true, ValueFromPipeline=$true)]
        [String]$User,
        [String]$Group = "BEH0",
        #[String]$AdminUser = "TDM.LOCAL\baraba",
        #[String]$vcadmin = "administrator@tdmadmin.vslocal",
        [PSCredential]$VCcred,
        [string]$RDPFilePath = "\\GONDOR.TDM.LOCAL\Students$"
        )

        Begin{
             #$secpasswd = ConvertTo-SecureString ???  -AsPlainText -Force             
             #$DomainCredential = New-Object System.Management.Automation.PSCredential ($AdminUser, (Read-Host "Enter $AdminUser password" -AsSecureString))
             if ($null -eq $VCcred){
                $vcadmin=whoami
                $VCcred = [System.Management.Automation.PSCredential]::new($vcadmin, (Read-Host "Enter $vcadmin password" -AsSecureString))
             }
                          
        }
        process{
           

            if ($null -eq (Get-Module VMware.PowerCLI)){
                Import-Module VMware.PowerCLI
            }

            if ($global:DefaultVIServers.count -eq 0){
                Connect-VIServer "vcenter.tdmadmin.local" -Credential $VCcred
            }
            
            $Server = "$User-20742B-LON-HOST1"
            $Username = "TDM.LOCAL\$User"

            try { 
                $vm = get-vm $Server -ErrorAction Stop
                write-host -ForegroundColor Green "Server $server already exists."                    
            } 
            catch {
                Write-Host "Creating $Server" -ForegroundColor Yellow
                $vm = New-VM -Template 20742B-LON-HOST1 -Name $Server -Datastore Net_Datastore -Location Networking -ResourcePool Resources -RunAsync
                while($vm.state -eq "Running")
                {
                    Start-Sleep 5
                    $vm = Get-Task -ID $vm.id
                }
                New-VIPermission -Entity $Server -Principal $Username -Role "VirtualMachineConsoleUser" -Propagate $true
                Start-VM $Server
                $vmIP = $null
                while ([string]::IsNullOrEmpty($vmIP)) {$vmIP = Get-VMGuest $Server | Select-Object  -ExpandProperty IPAddress | Where-Object {$_ -like "172.20.*"}}
                #create rdpfile                
                Write-Host "Creating $RDPFilePath\$Group\$User\$Server.rdp" -ForegroundColor Yellow 
                New-RDPFile -Server $Server -Path "$RDPFilePath\$Group\$User" -IP $vmIP                    
            }           
         
        }
}

Function New-20740VM{
    <#
    .SYNOPSIS
    Creates a 20742 Host1 Vertial Machine
    
    .DESCRIPTION
    Creates a VM with all the VM's for course 20744 nested in a single host.
    
    
    .PARAMETER User
    User for RDP file creation.
    
    .PARAMETER Group
    Group user is in for RDP file creation. Default is AB51 (Adv Dip Net Sec Cyber)
    
    .PARAMETER
    
    .EXAMPLE
    New-20744VM -User Student
    
    #>
        Param(           
            [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true, ValueFromPipeline=$true)]
            [String]$User,
            [String]$Group = "BEH0",
            #[String]$AdminUser = "TDM.LOCAL\baraba",
            #[String]$vcadmin = "administrator@tdmadmin.vslocal",
            [PSCredential]$VCcred,
            [string]$RDPFilePath = "\\GONDOR.TDM.LOCAL\Students$"
            )
    
            Begin{
                 #$secpasswd = ConvertTo-SecureString ???  -AsPlainText -Force             
                 #$DomainCredential = New-Object System.Management.Automation.PSCredential ($AdminUser, (Read-Host "Enter $AdminUser password" -AsSecureString))
                 if ($null -eq $VCcred){
                    $vcadmin=whoami
                    $VCcred = [System.Management.Automation.PSCredential]::new($vcadmin, (Read-Host "Enter $vcadmin password" -AsSecureString))
                 }
                              
            }
            process{
               
    
                if ($null -eq (Get-Module VMware.PowerCLI)){
                    Import-Module VMware.PowerCLI
                }
    
                if ($global:DefaultVIServers.count -eq 0){
                    Connect-VIServer "vcenter.tdmadmin.local" -Credential $VCcred
                }
                
                $Server = "$User-20740C-LON-HOST1"
                $Username = "TDM.LOCAL\$User"
    
                try { 
                    $vm = get-vm $Server -ErrorAction Stop
                    write-host -ForegroundColor Green "Server $server already exists."                    
                } 
                catch {
                    Write-Host "Creating $Server" -ForegroundColor Yellow
                    $vm = New-VM -Template 20740C-LON-HOST1 -Name $Server -Datastore Net_Datastore -Location Networking -ResourcePool Resources -RunAsync
                    while($vm.state -eq "Running")
                    {
                        Start-Sleep 5
                        $vm = Get-Task -ID $vm.id
                    }
                    New-VIPermission -Entity $Server -Principal $Username -Role "VirtualMachineConsoleUser" -Propagate $true
                    Start-VM $Server
                    $vmIP = $null
                    while ([string]::IsNullOrEmpty($vmIP)) {$vmIP = Get-VMGuest $Server | Select-Object -ExpandProperty IPAddress | Where-Object {$_ -like "172.20.*"}}
                    #create rdpfile                
                    Write-Host "Creating $RDPFilePath\$Group\$User\$Server.rdp" -ForegroundColor Yellow 
                    New-RDPFile -Server $Server -Path "$RDPFilePath\$Group\$User" -IP $vmIP                    
                }           
             
            }
    }

    Function New-20741VM{
        <#
        .SYNOPSIS
        Creates a 20742 Host1 Vertial Machine
        
        .DESCRIPTION
        Creates a VM with all the VM's for course 20744 nested in a single host.
        
        
        .PARAMETER User
        User for RDP file creation.
        
        .PARAMETER Group
        Group user is in for RDP file creation. Default is AB51 (Adv Dip Net Sec Cyber)
        
        .PARAMETER
        
        .EXAMPLE
        New-20744VM -User Student
        
        #>
            Param(           
                [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true, ValueFromPipeline=$true)]
                [String]$User,
                [String]$Group = "BEH0",
                #[String]$AdminUser = "TDM.LOCAL\baraba",
                #[String]$vcadmin = "administrator@tdmadmin.vslocal",
                [PSCredential]$VCcred,
                [string]$RDPFilePath = "\\GONDOR.TDM.LOCAL\Students$"
                )
        
                Begin{
                     #$secpasswd = ConvertTo-SecureString ???  -AsPlainText -Force             
                     #$DomainCredential = New-Object System.Management.Automation.PSCredential ($AdminUser, (Read-Host "Enter $AdminUser password" -AsSecureString))
                     if ($null -eq $VCcred){
                        $vcadmin=whoami
                        $VCcred = [System.Management.Automation.PSCredential]::new($vcadmin, (Read-Host "Enter $vcadmin password" -AsSecureString))
                     }
                                  
                }
                process{
                   
        
                    if ($null -eq (Get-Module VMware.PowerCLI)){
                        Import-Module VMware.PowerCLI
                    }
        
                    if ($global:DefaultVIServers.count -eq 0){
                        Connect-VIServer "vcenter.tdmadmin.local" -Credential $VCcred
                    }
                    
                    $Server = "$User-20741B-LON-HOST1"
                    $Username = "TDM.LOCAL\$User"
        
                    try { 
                        $vm = get-vm $Server -ErrorAction Stop
                        write-host -ForegroundColor Green "Server $server already exists."                    
                    } 
                    catch {
                        Write-Host "Creating $Server" -ForegroundColor Yellow
                        $vm = New-VM -Template 20741B-LON-HOST1 -Name $Server -Datastore Net_Datastore -Location Networking -ResourcePool Resources -RunAsync
                        while($vm.state -eq "Running")
                        {
                            Start-Sleep 5
                            $vm = Get-Task -ID $vm.id
                        }
                        New-VIPermission -Entity $Server -Principal $Username -Role "VirtualMachineConsoleUser" -Propagate $true
                        Start-VM $Server
                        $vmIP = $null
                        while ([string]::IsNullOrEmpty($vmIP)) {$vmIP = Get-VMGuest $Server | Select-Object -ExpandProperty IPAddress | Where-Object {$_ -like "172.20.*"}}
                        #create rdpfile                
                        Write-Host "Creating $RDPFilePath\$Group\$User\$Server.rdp" -ForegroundColor Yellow 
                        New-RDPFile -Server $Server -Path "$RDPFilePath\$Group\$User" -IP $vmIP                    
                    }           
                 
                }
        }

Function New-DipNetStage2FAVMs{
<#
.SYNOPSIS
Creates the virtualised environment for Diploma Stage 2 final assessment.

.DESCRIPTION
Creates 4 VMs - an SBS server, WRT gateway and 2 Windows 2019 Servers with 4x32G disks.


.PARAMETER User
User for RDP file creation.

.PARAMETER Group
Group user is in for RDP file creation. Default is AB51 (Adv Dip Net Sec Cyber)

.PARAMETER VLAN

.EXAMPLE
New-DipS2AssVMs -User Student -VLan 71

#>
    Param(           
        [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true, ValueFromPipeline=$true)]
        [String]$User,
        [String]$Group = "BEH6",
        [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true, ValueFromPipeline=$true)]
        [int]$VLan,
        [string]$VDSwitch = "DSwitch",
        #[String]$AdminUser = "TDM.LOCAL\baraba",
        #[String]$vcadmin = "administrator@tdmadmin.vslocal",
        [PSCredential]$VCcred,
        [string]$RDPFilePath = "\\GONDOR.TDM.LOCAL\Students$"
        )

        Begin{
             #$secpasswd = ConvertTo-SecureString ???  -AsPlainText -Force             
             #$DomainCredential = New-Object System.Management.Automation.PSCredential ($AdminUser, (Read-Host "Enter $AdminUser password" -AsSecureString))
             if ($null -eq $VCcred){
                $vcadmin=whoami
                $VCcred = [System.Management.Automation.PSCredential]::new($vcadmin, (Read-Host "Enter $vcadmin password" -AsSecureString))
             }
                          
        }

        process{
           

            if ($null -eq (Get-Module VMware.PowerCLI)){
                Import-Module VMware.PowerCLI
            }

            if ($global:DefaultVIServers.count -eq 0){
                Connect-VIServer "vcenter.tdmadmin.local" -Credential $VCcred
            }

            $Servers = "RBFE-SBS", "RBFE-DD-WRT", "RBFE-CS1", "RBFE-CS2"
            $Username = "TDM.LOCAL\$User"
            $LocalAdmin = [System.Management.Automation.PSCredential]::new("Administrator", (ConvertTo-SecureString "Pa55w.rd" -Force -AsPlainText))
            $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
            $spec.NestedHVEnabled = $true
            for ($i=0;$i -le 2;$i++){                
                $VLanId = $VLan+$i
                $vdpname = "Vlan$($VLanId)DPortGroup"
                $vdp = $null
                $vdp = Get-VDPortgroup -Name $vdpname -ErrorAction SilentlyContinue
                if([string]::IsNullOrEmpty($vdp)){
                    New-VDPortgroup -VDSwitch $VDSwitch -Name $vdpname -VlanId $VLanId -PortBinding Ephemeral -NumPorts 8
                    #Get-VDPortgroup $vdpname | Get-VDSecurityPolicy |  Set-VDSecurityPolicy -AllowPromiscuous $true -ForgedTransmits $true -MacChanges $true
                    Set-MacLearn -DVPortgroupName $vdpname -EnableMacLearn $true -EnablePromiscuous $false -EnableForgedTransmit $true -EnableMacChange $false                  
                }
            }
            foreach($Server in $Servers){
                $ServerName = "$User-$Server"
                try { 
                    $vm = VMware.VimAutomation.Core\Get-VM "" -ErrorAction Stop
                    write-host -ForegroundColor Green "Server $server already exists."                    
                } 
                catch {
                    Write-Host "Creating $ServerName" -ForegroundColor Yellow
                    if($Server -like "RBFE-CS*"){
                        $Template = "WinServer2019Base"                        
                        $vm = VMware.VimAutomation.Core\New-VM -Template $Template -Name "$ServerName" -Datastore Net_Datastore -Location NetDipStage2 -ResourcePool Resources -OSCustomizationSpec RBFE-Server -ErrorAction Continue -RunAsync
                        while($vm.state -eq "Running")
                        {
                            Start-Sleep 5
                            $vm = Get-Task -ID $vm.id
                        }
                        $vm =  VMware.VimAutomation.Core\get-vm $ServerName
                        VMware.VimAutomation.Core\Set-VM -VM $vm -MemoryGB 16 -CoresPerSocket 4 -NumCpu 8 -Confirm:$false
                        $vm.ExtensionData.ReconfigVM($spec)
                        New-HardDisk -VM "$ServerName" -DiskType Flat -CapacityGB 64 -StorageFormat Thin -Datastore Net_Datastore
                        New-HardDisk -VM "$ServerName" -DiskType Flat -CapacityGB 64 -StorageFormat Thin -Datastore Net_Datastore
                        New-HardDisk -VM "$ServerName" -DiskType Flat -CapacityGB 64 -StorageFormat Thin -Datastore Net_Datastore
                        New-HardDisk -VM "$ServerName" -DiskType Flat -CapacityGB 64 -StorageFormat Thin -Datastore Net_Datastore
                        #$na = VMware.VimAutomation.Core\Get-NetworkAdapter -VM $vm
                        New-NetworkAdapter -VM "$ServerName" -StartConnected:$true -Portgroup "Vlan$($VLan)DPortGroup" -Type Vmxnet3 -Confirm:$false
                        New-NetworkAdapter -VM "$ServerName" -StartConnected:$true -Portgroup "Vlan$($VLan+1)DPortGroup" -Type Vmxnet3 -Confirm:$false
                        New-NetworkAdapter -VM "$ServerName" -StartConnected:$true -Portgroup "Vlan$($VLan+2)DPortGroup" -Type Vmxnet3 -Confirm:$false
                        New-NetworkAdapter -VM "$ServerName" -StartConnected:$false -Portgroup "dpgExternal" -Type Vmxnet3 -Confirm:$false
                        #New-NetworkAdapter -VM "$ServerName" -StartConnected:$true -Portgroup "dpgTDM" -Type Vmxnet3 -Confirm:$false
                        
                    }
                    else{
                        $vm = VMware.VimAutomation.Core\New-VM -Template $Server -Name "$ServerName" -Datastore Net_Datastore -Location NetDipStage2 -ResourcePool Resources -ErrorAction Continue -RunAsync
                        while($vm.state -eq "Running")
                        {
                            Start-Sleep 5
                            $vm = Get-Task -ID $vm.id
                        }
                        $vm =  VMware.VimAutomation.Core\get-vm $ServerName
                        $na = VMware.VimAutomation.Core\Get-NetworkAdapter -VM $vm
                        if($Server -eq "RBFE-SBS"){                            
                            Set-NetworkAdapter -NetworkAdapter $na[0] -Portgroup "Vlan$($VLan)DPortGroup" -Confirm:$false
                            Set-NetworkAdapter -NetworkAdapter $na[1] -Portgroup "dpgTDM" -Confirm:$false
                        }
                        else{
                            Set-NetworkAdapter -NetworkAdapter $na[0] -Portgroup "dpgExternal" -Confirm:$false
                            Set-NetworkAdapter -NetworkAdapter $na[1] -Portgroup "Vlan$($VLan)DPortGroup" -Confirm:$false
                        }
                    }                    
                    New-VIPermission -Entity "$ServerName" -Principal $Username -Role "VirtualMachineConsoleUser" -Propagate $true
                    Start-VM "$ServerName"
                    if($Server -ne "RBFE-DD-WRT"){
                        $vmIP = $null
                        while ([string]::IsNullOrEmpty($vmIP)) {$vmIP = Get-VMGuest $ServerName | Select-Object -ExpandProperty IPAddress | Where-Object {$_ -like "172.20.*"}}
                        #create rdpfile
                        Invoke-Command -ComputerName $_ -Credential $LocalAdmin -ScriptBlock {
                            Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server'-name "fDenyTSConnections" -Value 0
                            Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -name "UserAuthentication" -Value 0
                            Enable-NetFirewallRule -DisplayGroup "Remote Desktop"            
                        }                
                        Write-Host "Creating $RDPFilePath\$Group\$User\$ServerName.rdp" -ForegroundColor Yellow 
                        New-RDPFile -Server "$ServerName" -Path "$RDPFilePath\$Group\$User" -IP $vmIP                    
                    }
                    New-Snapshot -VM $vm -name "Starting Image" -Confirm:$false -RunAsync:$true
                }     
            }      
         
        }
}

Function New-RBFEStg1vApp {
<#
.SYNOPSIS
Creates the virtualised environment for Diploma Networking Stage 1 and Adv Dip CyberSec Stage 1 final assessment.

.DESCRIPTION
Creates 4 VMs - an SBS server, WRT gateway and 2 Windows 2019 Servers with 4x32G disks.


.PARAMETER User
User for RDP file creation.

.PARAMETER Group
Group user is in for RDP file creation. Default is AB51 (Adv Dip Net Sec Cyber)

.PARAMETER VLAN

.EXAMPLE
New-RBFEStg1vApp -User Student -VLan 71 -VCCred $cred

#>
    Param(           
        [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true, ValueFromPipeline=$true)]
        [String]$User,
        [String]$Group = "AC20",
        [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true, ValueFromPipeline=$true)]
        [int]$VLan,
        [string]$VDSwitch = "DSwitch",
        #[String]$AdminUser = "TDM.LOCAL\baraba",
        #[String]$vcadmin = "administrator@tdmadmin.vslocal",
        [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true, ValueFromPipeline=$true)]
        [PSCredential]$VCcred
        )

        Begin{
             #$secpasswd = ConvertTo-SecureString ???  -AsPlainText -Force             
             #$DomainCredential = New-Object System.Management.Automation.PSCredential ($AdminUser, (Read-Host "Enter $AdminUser password" -AsSecureString))
             if ($null -eq $VCcred){
                $vcadmin=whoami
                $VCcred = [System.Management.Automation.PSCredential]::new($vcadmin, (Read-Host "Enter $vcadmin password" -AsSecureString))
             }
                          
        }

        process{
           

            if ($null -eq (Get-Module VMware.PowerCLI)){
                Import-Module VMware.PowerCLI
            }

            if ($global:DefaultVIServers.count -eq 0){
                Connect-VIServer "vcenter.tdmadmin.local" -Credential $VCcred
            }
            
            $Username = "TDM.LOCAL\$User"            
            if($Group -eq "AC20"){
                $InvLoc = "NetDipStage1"
                $Datastore = "Net_Datastore"
            }
            else{
                $InvLoc = "CyberAdvDip"
                $Datastore = "Cyber_Datastore"
            }
            $vAppName = "$User-RBFE-Stg1-vApp"
            
            New-VApp -VApp RBFE-Stg1-vApp -Name $vAppName -Datastore $Datastore -Location (Get-Cluster) -InventoryLocation $InvLoc -DiskStorageFormat Thin
            #New-VM -Name RBFE-Win10-Client -Datastore $Datastore -ResourcePool $vAppName -Template RBFE-Win10-Client -OSCustomizationSpec RBFE-Client -DiskStorageFormat Thin
            $VMadps = Get-VM -Location $vAppName | Get-NetworkAdapter 
            for ($i=0;$i -le 2;$i++){                              
                $VLanId = $VLan+$i
                $vdpname = "Vlan$($VLanId)DPortGroup"
                $vdp = $null
                $vdp = Get-VDPortgroup -Name $vdpname -ErrorAction SilentlyContinue
                if([string]::IsNullOrEmpty($vdp)){
                    New-VDPortgroup -VDSwitch $VDSwitch -Name $vdpname -VlanId $VLanId -PortBinding Ephemeral -NumPorts 8
                    #if($i -eq 0 -or $i -eq 2) {              
                        #Get-VDPortgroup $vdpname | Get-VDSecurityPolicy | Set-VDSecurityPolicy -AllowPromiscuous:$true -MacChanges:$true -ForgedTransmits:$true -Confirm:$false                        
                    #}
                    Set-MacLearn -DVPortgroupName $vdpname -EnableMacLearn $true -EnablePromiscuous $false -EnableForgedTransmit $true -EnableMacChange $false
                }
                $VMadps | Where-Object NetworkName -eq "dpgCyber6$($i+1)" | Set-NetworkAdapter -NetworkName $vdpname -Confirm:$false
            }
            New-VIPermission -Entity $vAppName -Principal $Username -Role "VirtualMachineUser" -Propagate $true            
            Get-VM -Location $vAppName | New-Snapshot -Name "Starting Image"
        }
}

Function New-RBFEStg2vApp {
<#
.SYNOPSIS
Creates the virtualised environment for Diploma Networking Stage 2 final assessment.

.DESCRIPTION
Creates 5 VMs - an SBS server, OpenWRT gateway, a Win 10 client and 2 Windows 2019 Servers with 4x128G disks.


.PARAMETER User
User for RDP file creation.

.PARAMETER Group
Group user is in for RDP file creation. Default is AB51 (Adv Dip Net Sec Cyber)

.PARAMETER VLAN

.EXAMPLE
New-RBFEStg2vApp -User Student -VLan 71 -VCCred $cred

#>
    Param(           
        [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true, ValueFromPipeline=$true)]
        [String]$User,
        [String]$Group = "BEH6",
        [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true, ValueFromPipeline=$true)]
        [int]$VLan,
        [string]$VDSwitch = "DSwitch",
        #[String]$AdminUser = "TDM.LOCAL\baraba",
        #[String]$vcadmin = "administrator@tdmadmin.vslocal",
        [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true, ValueFromPipeline=$true)]
        [PSCredential]$VCcred
        )

        Begin{
             #$secpasswd = ConvertTo-SecureString ???  -AsPlainText -Force             
             #$DomainCredential = New-Object System.Management.Automation.PSCredential ($AdminUser, (Read-Host "Enter $AdminUser password" -AsSecureString))
             if ($null -eq $VCcred){
                $vcadmin=whoami
                $VCcred = [System.Management.Automation.PSCredential]::new($vcadmin, (Read-Host "Enter $vcadmin password" -AsSecureString))
             }
                          
        }

        process{
           

            if ($null -eq (Get-Module VMware.PowerCLI)){
                Import-Module VMware.PowerCLI
            }

            if ($global:DefaultVIServers.count -eq 0){
                Connect-VIServer "vcenter.tdmadmin.local" -Credential $VCcred
            }
            
            $Username = "TDM.LOCAL\$User"            
            #if($Group -eq "AC20"){
                $InvLoc = "NetDipStage2"
                $Datastore = "Net_Datastore"
            #}
            #else{
            #    $InvLoc = "CyberAdvDip"
            #    $Datastore = "Cyber_Datastore"
            #}
            $vAppName = "RBFE-2012R2-Stg2-$User"
            
            New-VApp -VApp RBFE-2012R2-Stg2 -Name $vAppName -Datastore $Datastore -Location (Get-Cluster) -InventoryLocation $InvLoc -DiskStorageFormat Thin
            #New-VM -Name RBFE-Win10-Client -Datastore $Datastore -ResourcePool $vAppName -Template RBFE-Win10-Client -OSCustomizationSpec RBFE-Client -DiskStorageFormat Thin
            $VMadps = Get-VM -Location $vAppName | Get-NetworkAdapter 
            for ($i=0;$i -le 2;$i++){                              
                $VLanId = $VLan+$i
                $vdpname = "Vlan$($VLanId)DPortGroup"
                $vdp = $null
                $vdp = Get-VDPortgroup -Name $vdpname -ErrorAction SilentlyContinue
                if([string]::IsNullOrEmpty($vdp)){
                    New-VDPortgroup -VDSwitch $VDSwitch -Name $vdpname -VlanId $VLanId -PortBinding Ephemeral -NumPorts 8
                    #if($i -eq 0 -or $i -eq 2) {              
                        #Get-VDPortgroup $vdpname | Get-VDSecurityPolicy | Set-VDSecurityPolicy -AllowPromiscuous:$true -MacChanges:$true -ForgedTransmits:$true -Confirm:$false                        
                    #}
                    Set-MacLearn -DVPortgroupName $vdpname -EnableMacLearn $true -EnablePromiscuous $false -EnableForgedTransmit $true -EnableMacChange $false
                }
                $VMadps | Where-Object NetworkName -eq "dpgCyber6$($i+1)" | Set-NetworkAdapter -NetworkName $vdpname -Confirm:$false
            }
            New-VIPermission -Entity $vAppName -Principal $Username -Role "VirtualMachineUser" -Propagate $true
            Get-VM -Location $vAppName | New-Snapshot -Name "Starting Image"
        }
}

Function New-MS203vApp {
    <#
    .SYNOPSIS
    Creates the virtualised environment for Diploma Networking Stage 2 final assessment.
    
    .DESCRIPTION
    Creates 5 VMs - an SBS server, OpenWRT gateway, a Win 10 client and 2 Windows 2019 Servers with 4x128G disks.
    
    
    .PARAMETER User
    User for RDP file creation.
    
    .PARAMETER Group
    Group user is in for RDP file creation. Default is AB51 (Adv Dip Net Sec Cyber)
    
    .PARAMETER VLAN
    
    .EXAMPLE
    New-RBFEStg2vApp -User Student -VLan 71 -VCCred $cred
    
    #>
        Param(           
            [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true, ValueFromPipeline=$true)]
            [String]$User,
            [String]$Group = "AC20",
            [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true, ValueFromPipeline=$true)]
            [int]$VLan,
            [string]$VDSwitch = "DSwitch",
            #[String]$AdminUser = "TDM.LOCAL\baraba",
            #[String]$vcadmin = "administrator@tdmadmin.vslocal",
            [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true, ValueFromPipeline=$true)]
            [PSCredential]$VCcred
            )
    
            Begin{
                 #$secpasswd = ConvertTo-SecureString ???  -AsPlainText -Force             
                 #$DomainCredential = New-Object System.Management.Automation.PSCredential ($AdminUser, (Read-Host "Enter $AdminUser password" -AsSecureString))
                 if ($null -eq $VCcred){
                    $vcadmin=whoami
                    $VCcred = [System.Management.Automation.PSCredential]::new($vcadmin, (Read-Host "Enter $vcadmin password" -AsSecureString))
                 }
                              
            }
    
            process{
               
    
                if ($null -eq (Get-Module VMware.PowerCLI)){
                    Import-Module VMware.PowerCLI
                }
    
                if ($global:DefaultVIServers.count -eq 0){
                    Connect-VIServer "vcenter.tdmadmin.local" -Credential $VCcred
                }
                
                $Username = "TDM.LOCAL\$User"            
                #if($Group -eq "AC20"){
                    $InvLoc = "NetDipStage2"
                    $Datastore = "Net_Datastore"
                #}
                #else{
                #    $InvLoc = "CyberAdvDip"
                #    $Datastore = "Cyber_Datastore"
                #}
                $vAppName = "$User-MS-203vApp"
                
                New-VApp -VApp MS-203vApp -Name $vAppName -Datastore $Datastore -Location (Get-Cluster) -InventoryLocation $InvLoc -DiskStorageFormat Thin
                #New-VM -Name RBFE-Win10-Client -Datastore $Datastore -ResourcePool $vAppName -Template RBFE-Win10-Client -OSCustomizationSpec RBFE-Client -DiskStorageFormat Thin
                $VMadps = Get-VM -Location $vAppName | Get-NetworkAdapter 
                for ($i=0;$i -le 2;$i++){                              
                    $VLanId = $VLan+$i
                    $vdpname = "Vlan$($VLanId)DPortGroup"
                    $vdp = $null
                    $vdp = Get-VDPortgroup -Name $vdpname -ErrorAction SilentlyContinue
                    if([string]::IsNullOrEmpty($vdp)){
                        New-VDPortgroup -VDSwitch $VDSwitch -Name $vdpname -VlanId $VLanId -PortBinding Ephemeral -NumPorts 8
                        #if($i -eq 0 -or $i -eq 2) {              
                            #Get-VDPortgroup $vdpname | Get-VDSecurityPolicy | Set-VDSecurityPolicy -AllowPromiscuous:$true -MacChanges:$true -ForgedTransmits:$true -Confirm:$false                        
                        #}
                        Set-MacLearn -DVPortgroupName $vdpname -EnableMacLearn $true -EnablePromiscuous $false -EnableForgedTransmit $true -EnableMacChange $false
                    }
                    $VMadps | Where-Object NetworkName -eq "dpgCyber6$($i+1)" | Set-NetworkAdapter -NetworkName $vdpname -Confirm:$false
                }
                New-VIPermission -Entity $vAppName -Principal $Username -Role "VirtualMachineUser" -Propagate $true
                Get-VM -Location $vAppName | New-Snapshot -Name "Starting Image"
            }
    }
Function New-vSICMvApp {
<#
.SYNOPSIS
Creates the virtualised environment for Diploma Stage 2 final assessment.

.DESCRIPTION
Creates 4 VMs - an SBS server, WRT gateway and 2 Windows 2019 Servers with 4x32G disks.


.PARAMETER User
User for RDP file creation.

.PARAMETER Group
Group user is in for RDP file creation. Default is AB51 (Adv Dip Net Sec Cyber)

.PARAMETER VLAN

.EXAMPLE
New-vSICMvApp -User Student -VLan 71 -VCCred $cred

#>
    Param(           
        [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true, ValueFromPipeline=$true)]
        [String]$User,
        [String]$Group = "AC20",
        [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true, ValueFromPipeline=$true)]
        [int]$VLan,
        [string]$VDSwitch = "DSwitch",
        #[String]$AdminUser = "TDM.LOCAL\baraba",
        #[String]$vcadmin = "administrator@tdmadmin.vslocal",
        [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true, ValueFromPipeline=$true)]
        [PSCredential]$VCcred
        )

        Begin{
             #$secpasswd = ConvertTo-SecureString ???  -AsPlainText -Force             
             #$DomainCredential = New-Object System.Management.Automation.PSCredential ($AdminUser, (Read-Host "Enter $AdminUser password" -AsSecureString))
             if ($null -eq $VCcred){
                $vcadmin=whoami
                $VCcred = [System.Management.Automation.PSCredential]::new($vcadmin, (Read-Host "Enter $vcadmin password" -AsSecureString))
             }
                          
        }

        process{
           

            if ($null -eq (Get-Module VMware.PowerCLI)){
                Import-Module VMware.PowerCLI
            }

            if ($global:DefaultVIServers.count -eq 0){
                Connect-VIServer "vcenter.tdmadmin.local" -Credential $VCcred
            }
            
            $Username = "TDM.LOCAL\$User"            
            if($Group -eq "AC20"){
                $InvLoc = "NetDipStage1"
                $Datastore = "Net_Datastore"
            }
            else{
                $InvLoc = "CyberAdvDip"
                $Datastore = "Cyber_Datastore"
            }
            $vAppName = "$User-ICM-OPSCALE"
            
            New-VApp -VApp ICM-OPSCALE -Name $vAppName -Datastore $Datastore -Location (Get-Cluster) -InventoryLocation $InvLoc -DiskStorageFormat Thin
            $VMadps = Get-VM -Location $vAppName | Get-NetworkAdapter 
            for ($i=0;$i -le 5;$i++){                              
                $VLanId = $VLan+$i
                $vdpname = "Vlan$($VLanId)DPortGroup"
                $vdp = $null
                $vdp = Get-VDPortgroup -Name $vdpname -ErrorAction SilentlyContinue
                if([string]::IsNullOrEmpty($vdp)){
                    New-VDPortgroup -VDSwitch $VDSwitch -Name $vdpname -VlanId $VLanId -PortBinding Ephemeral -NumPorts 8
                    #if($i -eq 0 -or $i -eq 2) {              
                        #Get-VDPortgroup $vdpname | Get-VDSecurityPolicy | Set-VDSecurityPolicy -AllowPromiscuous:$true -MacChanges:$true -ForgedTransmits:$true -Confirm:$false                        
                    #}
                    Set-MacLearn -DVPortgroupName $vdpname -EnableMacLearn $true -EnablePromiscuous $false -EnableForgedTransmit $true -EnableMacChange $false
                }
                $VMadps | Where-Object NetworkName -eq "dpgCyber6$($i+1)" | Set-NetworkAdapter -NetworkName $vdpname -Confirm:$false
            }
            New-VIPermission -Entity $vAppName -Principal $Username -Role "VirtualMachineUser" -Propagate $true
            Get-VM -Location $vAppName | New-Snapshot -Name "Starting Image"
        }
}

Function New-ICMv8vApp {
    <#
    .SYNOPSIS
    Creates the virtualised environment for Diploma Stage 2 final assessment.
    
    .DESCRIPTION
    Creates 4 VMs - an SBS server, WRT gateway and 2 Windows 2019 Servers with 4x32G disks.
    
    
    .PARAMETER User
    User for RDP file creation.
    
    .PARAMETER Group
    Group user is in for RDP file creation. Default is AB51 (Adv Dip Net Sec Cyber)
    
    .PARAMETER VLAN
    
    .EXAMPLE
    New-vSICMvApp -User Student -VLan 71 -VCCred $cred
    
    #>
        Param(           
            [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true, ValueFromPipeline=$true)]
            [String]$User,
            [String]$Group = "AC20",
            [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true, ValueFromPipeline=$true)]
            [int]$VLan,
            [string]$VDSwitch = "DSwitch",
            #[String]$AdminUser = "TDM.LOCAL\baraba",
            #[String]$vcadmin = "administrator@tdmadmin.vslocal",
            [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true, ValueFromPipeline=$true)]
            [PSCredential]$VCcred
            )
    
            Begin{
                 #$secpasswd = ConvertTo-SecureString ???  -AsPlainText -Force             
                 #$DomainCredential = New-Object System.Management.Automation.PSCredential ($AdminUser, (Read-Host "Enter $AdminUser password" -AsSecureString))
                 if ($null -eq $VCcred){
                    $vcadmin=whoami
                    $VCcred = [System.Management.Automation.PSCredential]::new($vcadmin, (Read-Host "Enter $vcadmin password" -AsSecureString))
                 }
                              
            }
    
            process{
               
    
                if ($null -eq (Get-Module VMware.PowerCLI)){
                    Import-Module VMware.PowerCLI
                }
    
                if ($global:DefaultVIServers.count -eq 0){
                    Connect-VIServer "vcenter.tdmadmin.local" -Credential $VCcred
                }
                
                $Username = "TDM.LOCAL\$User"            
                if($Group -eq "AC20"){
                    $InvLoc = "NetDipStage1"
                    $Datastore = "Net_Datastore"
                }
                else{
                    $InvLoc = "CyberAdvDip"
                    $Datastore = "Cyber_Datastore"
                }
                $vAppName = "$User-VMWare-ICM8"
                
                New-VApp -VApp VMWare-ICM8 -Name $vAppName -Datastore $Datastore -Location (Get-Cluster) -InventoryLocation $InvLoc -DiskStorageFormat Thin
                $VMadps = Get-VM -Location $vAppName | Get-NetworkAdapter 
                for ($i=0;$i -le 2;$i++){                              
                    $VLanId = $VLan+$i
                    $vdpname = "Vlan$($VLanId)DPortGroup"
                    $vdp = $null
                    $vdp = Get-VDPortgroup -Name $vdpname -ErrorAction SilentlyContinue
                    if([string]::IsNullOrEmpty($vdp)){
                        New-VDPortgroup -VDSwitch $VDSwitch -Name $vdpname -VlanId $VLanId -PortBinding Ephemeral -NumPorts 8
                        #if($i -eq 0 -or $i -eq 2) {              
                            #Get-VDPortgroup $vdpname | Get-VDSecurityPolicy | Set-VDSecurityPolicy -AllowPromiscuous:$true -MacChanges:$true -ForgedTransmits:$true -Confirm:$false                        
                        #}
                        Set-MacLearn -DVPortgroupName $vdpname -EnableMacLearn $true -EnablePromiscuous $false -EnableForgedTransmit $true -EnableMacChange $false
                    }
                    $VMadps | Where-Object NetworkName -eq "dpgCyber6$($i)" | Set-NetworkAdapter -NetworkName $vdpname -Confirm:$false
                }
                New-VIPermission -Entity $vAppName -Principal $Username -Role "VirtualMachineUser" -Propagate $true
                Get-VM -Location $vAppName | New-Snapshot -Name "Starting Image"
            }
    }

Function New-DipNetStage1FAVMs{
<#
.SYNOPSIS
Creates the virtualised environment for Diploma Stage 2 final assessment.

.DESCRIPTION
Creates 4 VMs - an SBS server, WRT gateway and 2 Windows 2019 Servers with 4x32G disks.


.PARAMETER User
User for RDP file creation.

.PARAMETER Group
Group user is in for RDP file creation. Default is AB51 (Adv Dip Net Sec Cyber)

.PARAMETER VLAN

.EXAMPLE
New-DipS2AssVMs -User Student -VLan 71

#>
    Param(           
        [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true, ValueFromPipeline=$true)]
        [String]$User,
        [ValidateSet( "BEH6", "BCZ09")]
        [String]$Group = "BEH6",
        [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true, ValueFromPipeline=$true)]
        [int]$VLan,
        [string]$VDSwitch = "DSwitch",
        [switch]$HyperV = $false,
        #[String]$AdminUser = "TDM.LOCAL\baraba",
        #[String]$vcadmin = "administrator@tdmadmin.vslocal",
        [PSCredential]$VCcred,
        [string]$RDPFilePath = "\\GONDOR.TDM.LOCAL\Students$"
        )

        Begin{
             #$secpasswd = ConvertTo-SecureString ???  -AsPlainText -Force             
             #$DomainCredential = New-Object System.Management.Automation.PSCredential ($AdminUser, (Read-Host "Enter $AdminUser password" -AsSecureString))
             if ($null -eq $VCcred){
                #$vcadmin = whomai
                $VCcred = Get-Credential #[System.Management.Automation.PSCredential]::new($vcadmin, (Read-Host "Enter $vcadmin password" -AsSecureString))
                #$vcadmin = $VCcred.UserName
             }
                          
        }
        process{
           

            if ($null -eq (Get-Module VMware.PowerCLI)){
                Import-Module VMware.PowerCLI
            }

            if ($global:DefaultVIServers.count -eq 0){
                Connect-VIServer "vcenter.tdmadmin.local" -Credential $VCcred
            }
            #$LocalAdmin = [System.Management.Automation.PSCredential]::new("Administrator", (ConvertTo-SecureString "Pa55w.rd" -Force -AsPlainText))
            $VDSwitch = "DSwitch"
            for ($i=0;$i -le 2;$i++){                
                $VLanId = $VLan+$i
                $vdpname = "Vlan$($VLanId)DPortGroup"
                $vdp = $null
                $vdp = Get-VDPortgroup -Name $vdpname -ErrorAction SilentlyContinue
                if([string]::IsNullOrEmpty($vdp)){
                    New-VDPortgroup -VDSwitch $VDSwitch -Name $vdpname -VlanId $VLanId -PortBinding Ephemeral #-NumPorts 8
                    #Get-VDPortgroup $vdpname | Get-VDSecurityPolicy |  Set-VDSecurityPolicy -AllowPromiscuous $true -ForgedTransmits $true -MacChanges $true
                    Set-MacLearn -DVPortgroupName $vdpname -EnableMacLearn $true -EnablePromiscuous $false -EnableForgedTransmit $true -EnableMacChange $false
                }
            }
            
            $Servers = "RBFE-SS", "RBFE-DD-WRT", "RBFE-CS1", "RBFE-CS2", "RBFE-CL1"
            $Username = "TDM.LOCAL\$User"
            $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
            $spec.NestedHVEnabled = $true
            if($Group -eq "BEH6") { 
                $GroupLoc = "NetDipStage1"
                $Store = "Net_Datastore"
            }
            elseif($Group -eq "BCZ09") {
                $GroupLoc = "CyberAdvDip"
                $Store = "Cyber_Datastore"
            }

            foreach($Server in $Servers){
                $ServerName = "$User-$Server"
                try { 
                    $vm = VMware.VimAutomation.Core\Get-VM "" -ErrorAction Stop
                    write-host -ForegroundColor Green "Server $server already exists."                    
                } 
                catch {
                    Write-Host "Creating $ServerName" -ForegroundColor Yellow
                    if($Server -like "RBFE-CS*"){
                        # if($HyperV) {
                        #     $Template = "WinServer2019Base"
                        #     $vm = VMware.VimAutomation.Core\New-VM -Template $Template -Name "$ServerName" -Datastore $Store -Location $GroupLoc -ResourcePool Resources -OSCustomizationSpec RBFE-Server -RunAsync
                        #     while($vm.state -eq "Running")
                        #     {
                        #        Start-Sleep 5
                        #        $vm = Get-Task -ID $vm.id
                        #     }
                        #     $vm = get-vm $ServerName
                        #     $na = VMware.VimAutomation.Core\Get-NetworkAdapter -VM $vm                            
                        #     New-NetworkAdapter -VM "$ServerName" -StartConnected:$true -Portgroup "Vlan$($VLan)DPortGroup" -Type Vmxnet3 -Confirm:$false
                        #     New-NetworkAdapter -VM "$ServerName" -StartConnected:$true -Portgroup "Vlan$($VLan+1)DPortGroup" -Type Vmxnet3 -Confirm:$false
                        #     New-NetworkAdapter -VM "$ServerName" -StartConnected:$true -Portgroup "Vlan$($VLan+2)DPortGroup" -Type Vmxnet3 -Confirm:$false
                        #     New-NetworkAdapter -VM "$ServerName" -StartConnected:$false -Portgroup "dpgExternal" -Type Vmxnet3 -Confirm:$false
                        # }
                        # else {
                            $Template = "VMwareESXi"
                            $vm = VMware.VimAutomation.Core\New-VM -Template $Template -Name "$ServerName" -Datastore $Store -Location $GroupLoc -ResourcePool Resources -RunAsync
                            while($vm.state -eq "Running")
                            {
                                Start-Sleep 5
                                $vm = Get-Task -ID $vm.id
                            }
                            $vm = get-vm $ServerName
                            $na = VMware.VimAutomation.Core\Get-NetworkAdapter -VM $vm
                            Set-NetworkAdapter -NetworkAdapter $na -Portgroup "Vlan$($VLan)DPortGroup" -Confirm:$false
                            New-NetworkAdapter -VM "$ServerName" -StartConnected:$true -Portgroup "Vlan$($VLan+1)DPortGroup" -Type Vmxnet3 -Confirm:$false
                            New-NetworkAdapter -VM "$ServerName" -StartConnected:$true -Portgroup "Vlan$($VLan+2)DPortGroup" -Type Vmxnet3 -Confirm:$false
                            New-NetworkAdapter -VM "$ServerName" -StartConnected:$true -Portgroup "dpgExternal" -Type Vmxnet3 -Confirm:$false
                        #}
                        
                        VMware.VimAutomation.Core\Set-VM -VM $vm -MemoryGB 16 -CoresPerSocket 4 -NumCpu 8 -Confirm:$false -ErrorAction Continue
                        $vm.ExtensionData.ReconfigVM($spec)
                        
                    }
                    elseif($Server -eq "RBFE-CL1"){
                        $vm = VMware.VimAutomation.Core\New-VM -Template "Windows 10 Pro" -Name "$ServerName" -Datastore $Store -Location $GroupLoc -ResourcePool Resources -RunAsync
                        while($vm.state -eq "Running")
                        {
                            Start-Sleep 5
                            $vm = Get-Task -ID $vm.id
                        }                                  
                        New-NetworkAdapter -VM "$ServerName" -StartConnected:$true -Portgroup "Vlan$($VLan)DPortGroup" -Type Vmxnet3 -Confirm:$false
                    }
                    elseif($Server -eq "RBFE-SS"){
                        $vm = VMware.VimAutomation.Core\New-VM -Template $Server -Name "$ServerName" -Datastore $Store -Location $GroupLoc -ResourcePool Resources -RunAsync
                        while($vm.state -eq "Running")
                        {
                            Start-Sleep 5
                            $vm = Get-Task -ID $vm.id
                        }
                        $vm = get-vm $ServerName
                        $na = VMware.VimAutomation.Core\Get-NetworkAdapter -VM $vm
                        Set-NetworkAdapter -NetworkAdapter $na -Portgroup "Vlan$($VLan)DPortGroup" -Confirm:$false
                        New-NetworkAdapter -VM "$ServerName" -StartConnected:$true -Portgroup "Vlan$($VLan+1)DPortGroup" -Type Vmxnet3 -Confirm:$false
                        New-NetworkAdapter -VM "$ServerName" -StartConnected:$true -Portgroup "Vlan$($VLan+2)DPortGroup" -Type Vmxnet3 -Confirm:$false
                    }
                    else{
                        $vm = VMware.VimAutomation.Core\New-VM -Template $Server -Name "$ServerName" -Datastore $Store -Location $GroupLoc -ResourcePool Resources -OSCustomizationSpec RBFE-Server -RunAsync
                        while($vm.state -eq "Running")
                        {
                            Start-Sleep 5
                            $vm = Get-Task -ID $vm.id
                        }
                        $vm = get-vm $ServerName
                        $na = VMware.VimAutomation.Core\Get-NetworkAdapter -VM $vm
                        Set-NetworkAdapter -NetworkAdapter $na[0] -Portgroup "dpgExternal" -Confirm:$false
                        Set-NetworkAdapter -NetworkAdapter $na[1] -Portgroup "Vlan$($VLan)DPortGroup" -Confirm:$false
                    }
                #}               
                
                    # if($HyperV){
                    #     if($Server -ne "RBFE-DD-WRT"){
                    #         $vmIP = $null
                    #         while ([string]::IsNullOrEmpty($vmIP)) {$vmIP = Get-VMGuest $ServerName | select -ExpandProperty IPAddress | Where-Object {$_ -like "172.20.*"}}
                    #         #create rdpfile
                    #         Invoke-Command -ComputerName $vmIP -Credential $LocalAdmin -ScriptBlock {
                    #             Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server'-name "fDenyTSConnections" -Value 0
                    #             Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -name "UserAuthentication" -Value 0
                    #             Enable-NetFirewallRule -DisplayGroup "Remote Desktop"            
                    #         }                 
                    #         Write-Host "Creating $RDPFilePath\$Group\$User\$ServerName.rdp" -ForegroundColor Yellow 
                    #         New-RDPFile -Server "$ServerName" -Path "$RDPFilePath\$Group\$User" -IP $vmIP                    
                    #     }
                    #}
                    #else {
                        #if($Server -eq "RBFE-SS"){
                        #    $vmIP = $null
                        #    while ([string]::IsNullOrEmpty($vmIP)) {$vmIP = Get-VMGuest $ServerName | select -ExpandProperty IPAddress | Where-Object {$_ -like "172.20.*"}}
                        #    Invoke-Command -ComputerName $vmIP -Credential $LocalAdmin -ScriptBlock {
                        #        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server'-name "fDenyTSConnections" -Value 0
                        #        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -name "UserAuthentication" -Value 0
                        #        Enable-NetFirewallRule -DisplayGroup "Remote Desktop"            
                        #    } 
                        #    #create rdpfile                
                        #    Write-Host "Creating $RDPFilePath\$Group\$User\$ServerName.rdp" -ForegroundColor Yellow 
                        #    New-RDPFile -Server "$ServerName" -Path "$RDPFilePath\$Group\$User" -IP $vmIP                    
                        #}
                        #elseif ($Server -ne "RBFE-DD-WRT"){
                        #    Write-Host "Creating $RDPFilePath\$Group\$User\$Server.url" -ForegroundColor Yellow                 
                        #    New-UrlShortcut -Server $Server -Path "$FilePath\$Group\$User" -IP $vmIP
                        #}
                    }

                    New-Snapshot -VM (get-vm $ServerName)  -name "Starting Image" -Confirm:$false -RunAsync:$true
                    New-VIPermission -Entity "$ServerName" -Principal $Username -Role "VirtualMachineUser" -Propagate $true
                    #VMware.VimAutomation.Core\Start-VM "$ServerName"
                }     
            }      
         
}



Function New-VirtualSwitchPorts{
    Param($VDSwitch,
        $VLan,
        $Number
    )

    for ($i=0;$i -lt $Number;$i++){                
        $VLanId = $VLan+$i
        $vdpname = "Vlan$($VLanId)DPortGroup"
        $vdp = $null
        $vdp = Get-VDPortgroup -Name $vdpname -ErrorAction SilentlyContinue
        if([string]::IsNullOrEmpty($vdp)){
            New-VDPortgroup -VDSwitch $VDSwitch -Name $vdpname -VlanId $VLanId -PortBinding Ephemeral -NumPorts 8
            Get-VDPortgroup $vdpname | Get-VDSecurityPolicy |  Set-VDSecurityPolicy -AllowPromiscuous $true -ForgedTransmits $true -MacChanges $true                  
        }
    }

}

Function Get-StudentUser
{
    Param(
    [string]$StudentId,
    [string]$FirstName,
    [string]$LastName,
    [string]$AccountName,
    [switch]$Student=$false,
    [switch]$External=$false,
    [switch]$EPStudent=$false,
    [switch]$NBStudent=$false
    )
     
    $sb= "DC=TDM,DC=LOCAL"
    if($External)
    {
        $sb = "OU=ExternalStudents,DC=TDM,DC=LOCAL"
    }
    elseif($EPStudent) 
    {
        $sb = "OU=EPStudents,OU=EastPerth,DC=TDM,DC=LOCAL"
    }
    elseif($NBStudent) 
    {
        $sb = "OU=NBStudents,OU=Northbridge,DC=TDM,DC=LOCAL"
    }
    elseif($Student)
    {
        $sb = "OU=Students,DC=TDM,DC=LOCAL"
    }
    if([string]::IsNullOrEmpty($AccountName)){
        Get-ADUser -Filter * -SearchBase $sb -Properties Description,lastlogondate,passwordlastset, EmailAddress | Where-Object { $_.Description -like "$StudentId*$FirstName*$LastName*" }  #-or $_.Description -Contains  -or $_.Description -Contains }
    }
    else {
        Get-ADUser $AccountName -Properties description,lastlogondate,passwordlastset, EmailAddress | Where-Object { $_.Description -like "$StudentId*$FirstName*$LastName*"  } # -or $_.Description -Contains $FirstName -or $_.Description -Contains $LastName}        
    }
}

Function Get-LockedStudent{
    Param(
    [switch]$isExternal=$false,
    [switch]$EPStudent=$false,
    [switch]$NBStudent=$false
    )

    if($isExternal)
    {
        $sb = "OU=ExternalStudents,DC=TDM,DC=LOCAL"
    }
    elseif($EPStudent) 
    {
        $sb = "OU=EPStudents,OU=EastPerth,DC=TDM,DC=LOCAL"
    }
    elseif($NBStudent) 
    {
        $sb = "OU=NBStudents,OU=Northbridge,DC=TDM,DC=LOCAL"
    }
    else
    {
        $sb = "OU=Students,DC=TDM,DC=LOCAL"
    }
    Get-ADUser -Filter * -SearchBase $sb -Properties Description,lastlogondate,passwordlastset | Where-Object { $_.LockedOut -eq $true}
}
Function Enable-LocalRemoteDesktop {
    Param(
        $ComputerName,
        $LocalAdmin
        )
    Invoke-Command -ComputerName $vmIP -Credential $LocalAdmin -ScriptBlock {
                            Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server'-name "fDenyTSConnections" -Value 0
                            Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -name "UserAuthentication" -Value 0
                            Enable-NetFirewallRule -DisplayGroup "Remote Desktop"            
                        }
}
Function Enable-RemoteDesktop{
    Param(
    $ComputerName,
    $Username)

    Write-Verbose "Enabling remote desktop on $ComputerName in $Username"
    Invoke-Command -ComputerName $ComputerName -Args $Username -ScriptBlock { Param($u) 
        Add-LocalGroupMember "Remote Desktop Users" -Member $u
        Add-LocalGroupMember "Hyper-V Administrators" -Member $u
        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server'-name "fDenyTSConnections" -Value 0
        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -name "UserAuthentication" -Value 0
        Enable-NetFirewallRule -DisplayGroup "Remote Desktop"            
    }
}


Function New-VMwareICM67VM{
<#
.SYNOPSIS
Creates a VMwareICM67 Virtial Machine

.DESCRIPTION
Creates a VM with all the VM's for course 20744 nested in a single host.


.PARAMETER User
User for http file creation.

.PARAMETER Group
Group user is in for RDP file creation. Default is AB51 (Adv Dip Net Sec Cyber)

.PARAMETER

.EXAMPLE
New-20744VM -User Student

#>
    Param(           
        [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true, ValueFromPipeline=$true)]
        [String]$User,
        [String]$Group = "BEH6",
        #[String]$AdminUser = "TDM.LOCAL\baraba",
        #[String]$vcadmin = whoami,
        [PSCredential]$VCcred,
        [string]$FilePath = "\\GONDOR.TDM.LOCAL\Students$"
        )

        Begin{
             #$secpasswd = ConvertTo-SecureString ???  -AsPlainText -Force             
             #$DomainCredential = New-Object System.Management.Automation.PSCredential ($AdminUser, (Read-Host "Enter $AdminUser password" -AsSecureString))
             if ($null -eq $VCcred){
                $vcadmin = whoami
                $VCcred = [System.Management.Automation.PSCredential]::new($vcadmin, (Read-Host "Enter $vcadmin password" -AsSecureString))
             }
                          
        }
        process{
           

            if ($null -eq (Get-Module VMware.PowerCLI)){
                Import-Module VMware.PowerCLI
            }

            if ($global:DefaultVIServers.count -eq 0){
                Connect-VIServer "vcenter.tdmadmin.local" -Credential $VCcred
            }
            
            $Server = "VMware ICM 6.7-$User"
            $Username = "TDM.LOCAL\$User"



            try { 
                $vm = get-vm $Server -ErrorAction Stop
                write-host -ForegroundColor Green "Server $server already exists."                    
            } 
            catch {
                Write-Host "Creating $Server" -ForegroundColor Yellow
                $vm = New-VM -Template "VMware ICM 6.7" -Name $Server -Datastore Net_Datastore -Location Networking -ResourcePool Resources -RunAsync
                while($vm.state -eq "Running")
                {
                    Start-Sleep 5
                    $vm = Get-Task -ID $vm.id
                }
                $vm = get-vm $Server
                New-VIPermission -Entity $Server -Principal $Username -Role "VirtualMachineConsoleUser" -Propagate $true
                Start-VM $Server
                $vmIP = $null
                while ([string]::IsNullOrEmpty($vmIP)) {$vmIP = Get-VMGuest $Server | Select-Object -ExpandProperty IPAddress | Where-Object {$_ -like "172.20.*"}}
                #create urlfile                
                Write-Host "Creating $RDPFilePath\$Group\$User\$Server.url" -ForegroundColor Yellow                 
                New-UrlShortcut -Server $Server -Path "$FilePath\$Group\$User" -IP $vmIP                    
            }           
         
        }
}

function New-UrlShortcut{
    Param(
        $Server,
        $IP,
        $Path
    )
    $urlstring = @" 
[{000214A0-0000-0000-C000-000000000046}]
Prop3=19,11
[InternetShortcut]
IDList=
URL=https://$IP/ui
"@
    
    $urlstring > "$Path\$Server.url"
    
}

Function Get-MacLearn {
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Organization:  VMware
     Blog:          www.virtuallyghetto.com
     Twitter:       @lamw
        ===========================================================================
    .DESCRIPTION
        This function retrieves both the legacy security policies as well as the new
        MAC Learning feature and the new security policies which also live under this
        property which was introduced in vSphere 6.7
    .PARAMETER DVPortgroupName
        The name of Distributed Virtual Portgroup(s)
    .EXAMPLE
        Get-MacLearn -DVPortgroupName @("Nested-01-DVPG")
#>
    param(
        [Parameter(Mandatory=$true)][String[]]$DVPortgroupName
    )

    $minSwitchVersion = "6.6.0"

    foreach ($dvpgname in $DVPortgroupName) {
        $dvpg = Get-VDPortgroup -Name $dvpgname -ErrorAction SilentlyContinue
        $switchVersion = ($dvpg | Get-VDSwitch).Version
        if($dvpg -and [version]$switchVersion -ge [version]$minSwitchVersion) {
            $securityPolicy = $dvpg.ExtensionData.Config.DefaultPortConfig.SecurityPolicy
            $macMgmtPolicy = $dvpg.ExtensionData.Config.DefaultPortConfig.MacManagementPolicy

            $securityPolicyResults = [pscustomobject] @{
                DVPortgroup = $dvpgname;
                MacLearning = $macMgmtPolicy.MacLearningPolicy.Enabled;
                NewAllowPromiscuous = $macMgmtPolicy.AllowPromiscuous;
                NewForgedTransmits = $macMgmtPolicy.ForgedTransmits;
                NewMacChanges = $macMgmtPolicy.MacChanges;
                Limit = $macMgmtPolicy.MacLearningPolicy.Limit
                LimitPolicy = $macMgmtPolicy.MacLearningPolicy.limitPolicy
                LegacyAllowPromiscuous = $securityPolicy.AllowPromiscuous.Value;
                LegacyForgedTransmits = $securityPolicy.ForgedTransmits.Value;
                LegacyMacChanges = $securityPolicy.MacChanges.Value;
            }
            $securityPolicyResults
        } else {
            Write-Host -ForegroundColor Red "Unable to find DVPortgroup $dvpgname or VDS is not running $minSwitchVersion or later"
            break
        }
    }
}

Function Set-MacLearn {
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Organization:  VMware
     Blog:          www.virtuallyghetto.com
     Twitter:       @lamw
        ===========================================================================
    .DESCRIPTION
        This function allows you to manage the new MAC Learning capablitites in
        vSphere 6.7 along with the updated security policies.
    .PARAMETER DVPortgroupName
        The name of Distributed Virtual Portgroup(s)
    .PARAMETER EnableMacLearn
        Boolean to enable/disable MAC Learn
    .PARAMETER EnablePromiscuous
        Boolean to enable/disable the new Prom. Mode property
    .PARAMETER EnableForgedTransmit
        Boolean to enable/disable the Forged Transmit property
    .PARAMETER EnableMacChange
        Boolean to enable/disable the MAC Address change property
    .PARAMETER AllowUnicastFlooding
        Boolean to enable/disable Unicast Flooding (Default $true)
    .PARAMETER Limit
        Define the maximum number of learned MAC Address, maximum is 4096 (default 4096)
    .PARAMETER LimitPolicy
        Define the policy (DROP/ALLOW) when max learned MAC Address limit is reached (default DROP)
    .EXAMPLE
        Set-MacLearn -DVPortgroupName @("Nested-01-DVPG") -EnableMacLearn $true -EnablePromiscuous $false -EnableForgedTransmit $true -EnableMacChange $false
#>
    param(
        [Parameter(Mandatory=$true)][String[]]$DVPortgroupName,
        [Parameter(Mandatory=$true)][Boolean]$EnableMacLearn,
        [Parameter(Mandatory=$true)][Boolean]$EnablePromiscuous,
        [Parameter(Mandatory=$true)][Boolean]$EnableForgedTransmit,
        [Parameter(Mandatory=$true)][Boolean]$EnableMacChange,
        [Parameter(Mandatory=$false)][Boolean]$AllowUnicastFlooding=$true,
        [Parameter(Mandatory=$false)][Int]$Limit=4096,
        [Parameter(Mandatory=$false)][String]$LimitPolicy="DROP"
    )
    
    $minSwitchVersion = "6.6.0"

    foreach ($dvpgname in $DVPortgroupName) {
        $dvpg = Get-VDPortgroup -Name $dvpgname -ErrorAction SilentlyContinue
        $switchVersion = ($dvpg | Get-VDSwitch).Version
        if($dvpg -and [version]$switchVersion -ge [version]$minSwitchVersion) {
            #$originalSecurityPolicy = $dvpg.ExtensionData.Config.DefaultPortConfig.SecurityPolicy

            $spec = New-Object VMware.Vim.DVPortgroupConfigSpec
            $dvPortSetting = New-Object VMware.Vim.VMwareDVSPortSetting
            $macMmgtSetting = New-Object VMware.Vim.DVSMacManagementPolicy
            $macLearnSetting = New-Object VMware.Vim.DVSMacLearningPolicy
            $macMmgtSetting.MacLearningPolicy = $macLearnSetting
            $dvPortSetting.MacManagementPolicy = $macMmgtSetting
            $spec.DefaultPortConfig = $dvPortSetting
            $spec.ConfigVersion = $dvpg.ExtensionData.Config.ConfigVersion

            if($EnableMacLearn) {
                $macMmgtSetting.AllowPromiscuous = $EnablePromiscuous
                $macMmgtSetting.ForgedTransmits = $EnableForgedTransmit
                $macMmgtSetting.MacChanges = $EnableMacChange
                $macLearnSetting.Enabled = $EnableMacLearn
                $macLearnSetting.AllowUnicastFlooding = $AllowUnicastFlooding
                $macLearnSetting.LimitPolicy = $LimitPolicy
                $macLearnsetting.Limit = $Limit

                Write-Host "Enabling MAC Learning on DVPortgroup: $dvpgname ..."
                $task = $dvpg.ExtensionData.ReconfigureDVPortgroup_Task($spec)
                $task1 = Get-Task -Id ("Task-$($task.value)")
                $task1 | Wait-Task | Out-Null
            } else {
                $macMmgtSetting.AllowPromiscuous = $false
                $macMmgtSetting.ForgedTransmits = $false
                $macMmgtSetting.MacChanges = $false
                $macLearnSetting.Enabled = $false

                Write-Host "Disabling MAC Learning on DVPortgroup: $dvpgname ..."
                $task = $dvpg.ExtensionData.ReconfigureDVPortgroup_Task($spec)
                $task1 = Get-Task -Id ("Task-$($task.value)")
                $task1 | Wait-Task | Out-Null
            }
        } else {
            Write-Host -ForegroundColor Red "Unable to find DVPortgroup $dvpgname or VDS is not running $minSwitchVersion or later"
            break
        }
    }
}

Function New-E8vApp {
<#
.SYNOPSIS
Creates the virtualised environment for Diploma Stage 2 final assessment.

.DESCRIPTION
Creates 4 VMs - an SBS server, WRT gateway and 2 Windows 2019 Servers with 4x32G disks.


.PARAMETER User
User for RDP file creation.

.PARAMETER Group
Group user is in for RDP file creation. Default is AB51 (Adv Dip Net Sec Cyber)

.PARAMETER VLAN

.EXAMPLE
New-vSICMvApp -User Student -VLan 71 -VCCred $cred
#>

    Param(           
    [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true, ValueFromPipeline=$true)]
    [String]$User,
    [String]$Group = "E8",        
    [int]$VLan,
    [string]$VDSwitch = "DSwitch",
    #[String]$AdminUser = "TDM.LOCAL\baraba",
    #[String]$vcadmin = "administrator@tdmadmin.vslocal",
    [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true, ValueFromPipeline=$true)]
    [PSCredential]$VCcred
    )

    Begin{
            #$secpasswd = ConvertTo-SecureString ???  -AsPlainText -Force             
            #$DomainCredential = New-Object System.Management.Automation.PSCredential ($AdminUser, (Read-Host "Enter $AdminUser password" -AsSecureString))
            if ($null -eq $VCcred){
            $vcadmin=whoami
            $VCcred = [System.Management.Automation.PSCredential]::new($vcadmin, (Read-Host "Enter $vcadmin password" -AsSecureString))
            }
                          
    }

    process{
           

        if ($null -eq (Get-Module VMware.PowerCLI)){
            Import-Module VMware.PowerCLI
        }

        if ($global:DefaultVIServers.count -eq 0){
            Connect-VIServer "vcenter.tdmadmin.local" -Credential $VCcred
        }
            
        $Username = "TDM.LOCAL\$User"
        $SSOUsername = "TDMADMIN.VSLOCAL\$User"
        $InvLoc = "E8"
        $Datastore = "Net_Datastore"
        $vAppName = "$User-E8-VMs"
            
        New-VApp -VApp E8-VMs -Name $vAppName -Datastore $Datastore -Location (Get-Cluster) -InventoryLocation $InvLoc -DiskStorageFormat Thin
            
        if([string]::isnullorEmpty($VLan) -or $vlan -eq 0){
            $Vlan = 1 + (Get-vm | Get-NetworkAdapter |Sort-Object -Property NetworkName |Select-Object NetworkName -Unique -ExpandProperty NetworkName -Last 1).substring(4,3)                    
        }
        $vdpname = "Vlan$($VLan)DPortGroup"        
        New-VIPermission -Entity $vAppName -Principal $Username -Role "VirtualMachinePowerUser" -Propagate $true
        New-VIPermission -Entity $vAppName -Principal $SSOUsername -Role "VirtualMachinePowerUser" -Propagate $true        
        Get-VM -Location $vAppName | Get-NetworkAdapter | Where-Object NetworkName -eq "dpgCyber" | Set-NetworkAdapter -NetworkName $vdpname -Confirm:$false    
        Get-VM -Location $vAppName | New-Snapshot -Name "Starting Image"
    }
}

Function Add-E8ExamVM {
<#
.SYNOPSIS
Creates the virtualised environment for Diploma Stage 2 final assessment.

.DESCRIPTION
Creates 4 VMs - an SBS server, WRT gateway and 2 Windows 2019 Servers with 4x32G disks.


.PARAMETER User
User for RDP file creation.

.PARAMETER Group
Group user is in for RDP file creation. Default is AB51 (Adv Dip Net Sec Cyber)

.PARAMETER VLAN

.EXAMPLE
New-vSICMvApp -User Student -VLan 71 -VCCred $cred
#>

    Param(           
    [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true, ValueFromPipeline=$true)]
    [String]$User,       
    [int]$VLan,
    [string]$VDSwitch = "DSwitch",
    #[String]$AdminUser = "TDM.LOCAL\baraba",
    #[String]$vcadmin = "administrator@tdmadmin.vslocal",
    [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true, ValueFromPipeline=$true)]
    [PSCredential]$VCcred
    )

    Begin{
            #$secpasswd = ConvertTo-SecureString ???  -AsPlainText -Force
    }

    process{
           

        if ($null -eq (Get-Module VMware.PowerCLI)){
            Import-Module VMware.PowerCLI
        }

        if ($global:DefaultVIServers.count -eq 0){
            Connect-VIServer "vcenter.tdmadmin.local" -Credential $VCcred
        }
            
        #$Username = "TDM.LOCAL\$User"
        #$SSOUsername = "TDMADMIN.VSLOCAL\$User"
        #$InvLoc = "E8"
        $Datastore = "Net_Datastore"
        $vAppName = "$User-E8-VMs"
            
        New-VM -Name Exam -Template Exam -ResourcePool $vAppName -DiskStorageFormat Thin -Datastore $Datastore
        $vm = get-vm -Location $vAppName -Name Exam        
        $vdpname = (Get-VM -Name "DepartmentServer" -Location $vAppName | Get-NetworkAdapter).NetworkName
        Get-NetworkAdapter -VM $vm | Set-NetworkAdapter -NetworkName $vdpname -Confirm:$false            
        New-Snapshot -VM $vm -Name "Starting Image"
    }
}

Function Reset-StudentUserPassword
{
    Param( 
    [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true, ValueFromPipeline=$true)]
    [Microsoft.ActiveDirectory.Management.ADUser]$User    
    )
    
    Set-ADAccountPassword -Identity $User -NewPassword (ConvertTo-SecureString "Password1" -AsPlainText -Force) -Reset
    Set-ADUser -Identity $User -ChangePasswordAtLogon $true
    Unlock-ADAccount -Identity $User
}

Function Stop-LabComputers
{
    param(
    [System.Management.Automation.PSCredential] $Credential)

    if([String]::IsNullOrEmpty($Credential))
    {
        $cred = Get-Credential    
    }
    else
    {
        $cred = $Credential
    }

    $labs = "A103", "A104", "A105", "A106", "A114", "A116", "A118", "A133", "A135", "A137", "A143"
    
    foreach ($lab in $labs){
        1 .. 9 | ForEach-Object {if(Test-Connection "$lab-0$_" -Count 1 -Quiet){
                Write-Host -ForegroundColor Green "$lab-0$_ -> Up"
                Invoke-Command -ScriptBlock {Stop-Computer -Force -ErrorAction SilentlyContinue } -ComputerName "$lab-0$_" -Credential $cred -AsJob
            } 
            else {
                Write-Host -ForegroundColor Red "$lab-0$_ -> Down"
            }
        }
        10 .. 30 | ForEach-Object {if(Test-Connection "$lab-$_" -Count 1 -Quiet){
                Write-Host -ForegroundColor Green "$lab-$_ -> Up"
                Invoke-Command -ScriptBlock {Stop-Computer -Force -ErrorAction SilentlyContinue} -ComputerName "$lab-$_" -Credential $cred -AsJob
            }
            else
            {
                Write-Host -ForegroundColor Red "$lab-$_ -> Down"
            }
        }
    }
}

Function New-AdvDipStg2RBFEVMs
{
    param(
    [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true, ValueFromPipeline=$true)]
    [String]$User,
    [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true, ValueFromPipeline=$true)]
    [Int]$VLan
    )

    $VMs = Get-ChildItem "C:\ClusterStorage\StudentVMs\Export"
    
    foreach ($VM in $VMs)
    {
        $Path = "C:\ClusterStorage\StudentVMs\$User-$($VM.Name)"
        Copy-Item $VM.FullName -Destination $Path -Recurse
        $VMcx = Get-Item "$($Path)\Virtual Machines\*.vmcx"        
        $Report = Compare-VM -Path $VMcx -Copy -GenerateNewId -VhdDestinationPath "$($Path)\Virtual Hard Disks"
        $VMName = "$($User)-$($Report.VM.Name)"
        Rename-VM $Report.VM -NewName $VMName
        foreach ($VMHDD in $Report.Incompatibilities)
        {
            $VMHDDPath = $VMHDD.Source.Path -ireplace [regex]::Escape("hyper-v\"), "$($User)-"
            $VMHDD.Source | Set-VMHardDiskDrive -Path $VMHDDPath            
        }
        if($VMName.Contains("Client"))
        {
            Set-VMNetworkAdapterVlan -VMNetworkAdapter $Report.VM.NetworkAdapters[0] -VlanId $VLan -Access
        }
        elseif($VMName.Contains("N1"))
        {
            <# Action when all if and elseif conditions are false #>
            Set-VMNetworkAdapterVlan -VMNetworkAdapter $Report.VM.NetworkAdapters[0] -VlanId $VLan -Access
            Set-VMNetworkAdapterVlan -VMNetworkAdapter $Report.VM.NetworkAdapters[1] -VlanId ($VLan+1) -Access
            Set-VMNetworkAdapterVlan -VMNetworkAdapter $Report.VM.NetworkAdapters[2] -VlanId ($VLan+2) -Access
        }
        elseif($VMName.Contains("N2"))
        {
            <# Action when all if and elseif conditions are false #>
            Set-VMNetworkAdapterVlan -VMNetworkAdapter $Report.VM.NetworkAdapters[1] -VlanId $VLan -Access
            Set-VMNetworkAdapterVlan -VMNetworkAdapter $Report.VM.NetworkAdapters[2] -VlanId ($VLan+1) -Access
            Set-VMNetworkAdapterVlan -VMNetworkAdapter $Report.VM.NetworkAdapters[3] -VlanId ($VLan+2) -Access
        }
        Import-VM -CompatibilityReport $Report
        Remove-Item "$($Path)\Virtual Hard Disks\*.vhdx"
        #Start-VM $VMName
    }

}

Function Get-LoggedInUsers
{
    param(
    [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true, ValueFromPipeline=$true)]
    [String]$Room
    )
    # Define the list of remote computers
    $computers = 1..9 | ForEach-Object {"$Room-0$_"}   # Replace with your computer names or IP addresses
    $computers += 10..25 | ForEach-Object {"$Room-$_"}

    # Loop through each computer
    foreach ($computer in $computers) {
        if (Test-Connection -ComputerName $computer -Count 1 -Quiet) {
            try {
                # Query the logged-in user using Get-CimInstance
                $loggedInUser = Get-CimInstance -ComputerName $computer -ClassName Win32_ComputerSystem | Select-Object -ExpandProperty UserName

                if ($loggedInUser) {
                    Write-Host -ForegroundColor Green "Logged-in user on $($computer): $loggedInUser"
                } else {
                    Write-Host -ForegroundColor DarkRed "No user is currently logged in on $computer."
                }
            } catch {
                Write-Host -ForegroundColor Red "Failed to query $computer. Error: $_"
            }
        }
        else
        { 
            Write-Host -ForegroundColor Red "$computer appears to be off."        
        }
    }
}

Function New-TAFEUserInvitation{

    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [object[]]$Users
    )

    foreach ($User in $Users) {
        try {
            New-MgInvitation -InvitedUserEmailAddress $User `
                -InviteRedirectUrl "https://portal.azure.com" `
                -InvitedUserMessageInfo @{
                    CustomizedMessageBody = 
                    "Hi,
                        You have been invited to access our Azure tenant.
                        If you have any issues signing in, please contact adt@nmtafe.wa.edu.au.

                        Thanks,
                        The TDM Network team"
                    MessageLanguage = "en-AU"
                } `
                -SendInvitationMessage:$true

            Write-Host "✅ Invited $($User.Email)" -ForegroundColor Green
        }
        catch {
            Write-Host "❌ Failed to invite $($User.Email): $_" -ForegroundColor Red
        }
    }
}

Class Student
{
    [String]$Title
    [String]$Firstname
    [String]$Middlename
    [String]$Lastname
    [String]$StudentId
    [String]$Group
    [Boolean]$External
}

$Global:Rooms = "A103", "A104", "A105", "A106", "A114", "A116", "A118", "A133", "A135", "A137", "A143"

Export-ModuleMember Invite-TAFEUser, New-AdvDipStg2RBFEVMs, Reset-StudentUserPassword, New-ICMv8vApp, Add-E8ExamVM, New-E8vApp, New-ExchangeSession, Get-MacLearn, Set-MacLearn, New-MS203vApp, New-RBFEStg1vApp, New-RBFEStg2vApp, New-DipNetStage1FAVMs, New-VMwareICM67VM, Enable-RemoteDesktop, New-StudentUser, New-StudentAdmin, New-RDPFile, New-MSSQLVM, New-20740VM, New-20741VM, New-20742VM, New-20744VM, New-20745VM, New-DipNetStage2FAVMs, Get-StudentUser, Get-LockedStudent, New-vSICMvApp, Stop-LabComputers, Get-LoggedInUsers
