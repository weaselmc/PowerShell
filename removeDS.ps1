for($i=1; $i -le 25;$i++)
{
    if($i -le 9)
    {
        $Server = "A104-0$i" 
        }
    else
    {
        $Server = "A104-$i"
        }
    Invoke-Command -ComputerName $Server -ScriptBlock {
        Get-HNSNetwork | Remove-HNSNetwork
        }
        
    Write-Host "$Server - Default Switch Removed" -ForegroundColor Green
   
}
