$Pass = ConvertTo-SecureString "password" -AsPlainText -Force
$Cred = New-Object System.Management.Automation.PSCredential (".\Administrator", $pass)

for($i=41;$i -le 50;$i++)
{
    if($i -le 9)
    {
        $cs = "00" + $i
    }
    elseif ($i -le 99)
    {
        $cs = "0" + $i
    }
    else
    {
        $cs = $i
    }

    $Server = "MSSQLServer$cs"
    $vm = get-vm $Server
    #read-host "$Server Enter"
    Write-Host -ForegroundColor Cyan "Changing $Server..."
    Invoke-Command -VMName $Server -Credential $Cred -ArgumentList $Server -ScriptBlock {
    Param($Server)
        $Pass = ConvertTo-SecureString "password" -AsPlainText -Force
        $Cred = New-Object System.Management.Automation.PSCredential ("tdm\buttsm.admin", $Pass)
        #Rename-Computer $Server -Force
        #Restart-Computer
        Add-Computer -Credential $Cred -DomainName "tdm.local" -Restart        
    }
    
}

