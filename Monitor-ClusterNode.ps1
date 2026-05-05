while($true) 
{
    Write-Verbose "Checking Nodes ..."
    Get-ClusterNode | % { 
        if($_.State -ne "Up")
        {
            Write-Host -ForegroundColor Magenta "[$(get-date)] Restarting Node $($_.Name)"
            Resume-ClusterNode -Name $_.Name -Failback NoFailback
        }
    }
    sleep -Seconds 30    
}