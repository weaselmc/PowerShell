for($i = 1; $i -le 20;$i++)
{
    $pc = "A143-"
    if($i -le 9)
    {
        $pc = $pc + "0" + $i + "-SVR"
    }
    else
    {
        $pc = $pc + $i + "-SVR"
    }
    
    Invoke-Command -ComputerName $pc -ArgumentList $pc -ScriptBlock { 
        try{
            Add-LocalGroupMember -Group "Hyper-V Administrators" -Member "tdm\Students"
            Write-Host -ForegroundColor Green "$pc modified."
        }
        catch
        {
            Write-Host -ForegroundColor Yellow "Error:$Error[0].ErrorDetails"
        }
    }
    Write-Host -ForegroundColor Green "$pc modified."    
}