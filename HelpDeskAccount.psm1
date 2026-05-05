function New-HelpDeskAccountTrigger{
    param(
        [AdminUsers]$AdminUser, 
        $Date = (Get-Date), 
        [Sessions]$Session 
    )

    $Day = (Get-Date $Date).ToShortDateString()

    if($Session -eq "Morning") {
        $Start = Get-Date "$Day 8:00:00 AM"
        $End = Get-Date "$Day 12:00:00 PM"
    }
    else {
        $Start = Get-Date "$Day 12:00:00 PM"
        $End = Get-Date "$Day 4:00:00 PM"
    }
           
    
    #$SecurePassword = Read-Host -AsSecureString
    #$UserName = "tdmadmin\mark"
    #$Credentials = New-Object System.Management.Automation.PSCredential -ArgumentList $UserName, $SecurePassword
    #schedule enable account
    #$Start = (Get-Date).AddSeconds(15)
    $admin = Get-ADUser "$AdminUser.admin"
    #$action = New-ScheduledTaskAction -Execute 'Powershell.exe' -Argument "-WindowStyle Hidden -command {Enable-ADAccount $AdminUser.admin}"
    $trigger =   New-JobTrigger -At $Start -Once    
    #Register-ScheduledTask -TaskName "Enable $AdminUser.admin" -Trigger $trigger -Action $action -User $UserName -Password $Credentials.GetNetworkCredential().Password 
    Register-ScheduledJob -Name "Enable $($admin.SamAccountName) $($Start.ToString("dd-MMM-yyyy tt"))" -ArgumentList $admin -ScriptBlock { param($u) Enable-ADAccount $u} -Trigger $trigger
    
    #schedule disable account
    #$action = New-ScheduledTaskAction -Execute 'Powershell.exe' -Argument '-NoProfile -WindowStyle Hidden -command {Disable-ADAccount $AdminUser.admin}'
    $trigger =  New-JobTrigger -at $End -Once    
    Register-ScheduledJob -Name "Disable $($admin.SamAccountName)  $($End.ToString("dd-MMM-yyyy tt"))" -ArgumentList $admin -ScriptBlock { param($u) Disable-ADAccount $u} -Trigger $trigger
}

Enum Sessions{
    Morning
    Afternoon
}

Enum AdminUsers{
    MELVIC
    REESDA
    NEJADM
}