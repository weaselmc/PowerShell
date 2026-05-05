$cred = [System.Management.Automation.PSCredential]::new("tdm\baraba", (Read-Host "Enter password" -AsSecureString))
$group = "BEH0"
$users = Get-ADGroupMember $group | Get-ADUser
$current = 0
"ADAccount, ComputerName" > "BEH0-ComputerList.csv"

for($i = 1; $i -lt 10; $i++) {
    $student = "TDM\$($users[$current].SamAccountName)"
    $server = "A143-0$i-SVR"
    New-RDPFile -Server $server -Username $student -Path "\\gondor.tdm.local\Students$\$Group\$($users[$current].SamAccountName)"
    Invoke-Command -Credential $cred -ArgumentList $student -ComputerName $server -ScriptBlock { 
        PARAM($s)
         
            Add-LocalGroupMember -Group "Remote Desktop Users" -Member $s
            Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server'-name "fDenyTSConnections" -Value 0
            Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -name "UserAuthentication" -Value 1
            Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
        }
    Write-Host "$student, $server"
    "$student, $server" >> "BEH0-ComputerList.csv"
    $current++    
}

for($i = 10; $i -lt 21; $i++) {
    $student = "TDM\$($users[$current].SamAccountName)"
    $server = "A143-$i-SVR"
    New-RDPFile -Server $server -Username $student -Path "\\gondor.tdm.local\Students$\$Group\$($users[$current].SamAccountName)"
    Invoke-Command -Credential $cred -ArgumentList $student -ComputerName $server -ScriptBlock { 
        PARAM($s)
         
            Add-LocalGroupMember -Group "Remote Desktop Users" -Member $s
            Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server'-name "fDenyTSConnections" -Value 0
            Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -name "UserAuthentication" -Value 1
            Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
        }
    Write-Host "$student, $server"
    "$student, $server" >> "BEH0-ComputerList.csv"
    $current++
}

for($i = 1; $i -lt 10; $i++) {
    $student = "TDM\$($users[$current].SamAccountName)"
    $server = "A133-0$i-SVR"
    New-RDPFile -Server $server -Username $student -Path "\\gondor.tdm.local\Students$\$Group\$($users[$current].SamAccountName)"
    Invoke-Command -Credential $cred -ArgumentList $student -ComputerName $server -ScriptBlock { 
        PARAM($s)
         
            Add-LocalGroupMember -Group "Remote Desktop Users" -Member $s
            Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server'-name "fDenyTSConnections" -Value 0
            Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -name "UserAuthentication" -Value 1
            Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
        }
    Write-Host "$student, $server"
    "$student, $server" >> "BEH0-ComputerList.csv"
    $current++
}

for($i = 10; $i -lt 17; $i++) {
    if($i -ne 11) {
        $student = "TDM\$($users[$current].SamAccountName)"
        $server = "A133-$i-SVR"
        New-RDPFile -Server $server -Username $student -Path "\\gondor.tdm.local\Students$\$Group\$($users[$current].SamAccountName)"
        Invoke-Command -Credential $cred -ArgumentList $student -ComputerName $server -ScriptBlock { 
        PARAM($s)
         
            Add-LocalGroupMember -Group "Remote Desktop Users" -Member $s
            Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server'-name "fDenyTSConnections" -Value 0
            Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -name "UserAuthentication" -Value 1
            Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
        }
        Write-Host "$student, $server"
        "$student, $server" >> "BEH0-ComputerList.csv"
        $current++
    }
}
