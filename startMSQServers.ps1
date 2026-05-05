$vms = Get-ClusterResource | ? {$_.Name -like "Virtual Machine MSSQLServer*"} | Get-VM

$Cred = Get-Credential "Administrator"
$admincreds = Get-Credential "tdm\buttsm.admin"

foreach ($vm in $vms)
{
    Write-Host -ForegroundColor Magenta "Configuring $($vm.name)"
    $response = Read-Host "Skip Host (Y/N)"
    if($response -eq "n")
    {
        start-vm $vm
        $vmIP = $null
        While([string]::IsNullOrEmpty($vmIP))
        {
            try
            {
                $vmIP = $(Get-VMNetworkAdapter $vm).IPAddresses[0]          
            } 
            catch
            { 
                Write-Host -ForegroundColor Yellow "Starting vm ..."
                Start-Sleep -Seconds 5
            }        
        }
    
        Write-Host -ForegroundColor Green "VM Found on $vmIP"
        Read-Host "Set Administrator password before pressing enter!"    
        Invoke-Command -VMName $vm.Name -Credential $Cred -ArgumentList $vm.Name,$admincreds -ScriptBlock {       
            Param($name,$adcreds)
            Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server'-name "fDenyTSConnections" -Value 0
            Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -name "UserAuthentication" -Value 1
            Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
            Rename-Computer $name
            add-computer -DomainCredential $adcreds -DomainName tdm.local -Restart 
            Write-Host -ForegroundColor Cyan "Update Complete Restarting $name"            
        }
    }
}