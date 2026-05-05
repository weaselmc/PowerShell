Invoke-Command -ComputerName "bilbo","bungo","drogo","frodo","merry","pippen","samwise" -ScriptBlock {
    $RegKey ="HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002BE10318}"
    Get-ChildItem -Path $RegKey -ErrorAction SilentlyContinue| % {
        $path = $_.PSPath
        Get-Itemproperty $path | where {$_.driverdesc -eq "Hyper-V Virtual Ethernet Adapter" -and $_.Characteristics -eq "41"} | % {
            Set-ItemProperty $path -Name "*JumboPacket" -Value "9014"
        }
    }
}