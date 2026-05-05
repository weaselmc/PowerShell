

Invoke-Command -VMName $Server -Credential $Cred -ArgumentList (,$vmn) -ScriptBlock {       
        Param($nics)
        #Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server'-name "fDenyTSConnections" -Value 0
        #Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -name "UserAuthentication" -Value 1
        #Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
        Write-Host -ForegroundColor Cyan $nics
        Foreach($nic in $nics)
        {
            $Mac = "$($nic.MacAddress[0])$($nic.MacAddress[1])-$($nic.MacAddress[2])$($nic.MacAddress[3])-$($nic.MacAddress[4])$($nic.MacAddress[5])-$($nic.MacAddress[6])$($nic.MacAddress[7])-$($nic.MacAddress[8])$($nic.MacAddress[9])-$($nic.MacAddress[10])$($nic.MacAddress[11])"  
            Write-Host -ForegroundColor Cyan $Mac
            Get-NetAdapter | ? { $_.MacAddress -eq "$Mac"}
            $adapter = Get-NetAdapter | ? { $_.MacAddress -eq "$Mac"}
            Write-Host -ForegroundColor Cyan $adapter
            $newname = $nic.SwitchName.Split(" ")[0]
            $adapter | Rename-NetAdapter -NewName $newname
        }                
    }
    