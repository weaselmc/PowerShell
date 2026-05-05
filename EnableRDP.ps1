for($i=1; $i -le 25;$i++)
{
    if($i -le 9)
    {
        $Server = "MSSQL00$i" 
        }
    else
    {
        $Server = "MSSQL0$i"
        }
    Invoke-Command -ComputerName $Server -ScriptBlock {
        set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server'-name "fDenyTSConnections" -Value 0
        set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -name "UserAuthentication" -Value 1
        Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
        }
        
    Write-Host "$Server - RDP Enabled" -ForegroundColor Green
   
}
