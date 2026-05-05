Param(
    $ComputerName,
    $Username)

    Invoke-Command -ComputerName $ComputerName -Args $Username -ScriptBlock { Param($u) 
            Add-LocalGroupMember "Remote Desktop Users" -Member $u
            Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server'-name "fDenyTSConnections" -Value 0
            Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -name "UserAuthentication" -Value 1
            Enable-NetFirewallRule -DisplayGroup "Remote Desktop"            
            }