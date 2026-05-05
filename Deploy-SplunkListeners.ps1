
$labs = "A103", "A104", "A105", "A106", "A114", "A118", "A133", "A135", "A137", "A143", "A116"
$computers = $null
#$password = Read-Host "Splunk Admin Password"
foreach ($lab in $labs) {
    $computers += 1..9 | % {"$lab-0$_"}
    $computers += 10 .. 25| % {"$lab-$_"}
}
$exceptions= #"A133-10","A133-11", "A114-11","A116-21","A116-01"

$ErrorActionPreference = "SilentlyContinue"
foreach ($computer in $computers){
    Deploy-SplunkListener -Computer $computer
}
$ErrorActionPreference = "Continue"

function Deploy-SplunkListener{
    param(
        [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        $Computer
    )

    if((Test-Connection $computer -Count 1 -Quiet) -eq $true)
    {                   
        try {
            if([String]::IsNullOrEmpty((get-item "\\$computer.tdm.local\C$\Windows\Temp\Splunk"))){
                Copy-Item "C:\Windows\Temp\Splunk" "\\$computer.tdm.local\C$\Windows\Temp" -Recurse
                "Copied files to $computer" >> debug.txt
            }
        }
        catch {
            "$computer : $_" >> error.txt
        }
        try {
            Start-Job -ArgumentList $computer -ScriptBlock { param($computer)
                Invoke-Command -ComputerName "$computer.tdm.local" -ScriptBlock { & cmd /c "wmic product where ""description='UniversalForwarder'"" uninstall"}
                Invoke-Command -ComputerName "$computer.tdm.local" { & cmd /c "setx SPLUNK_HOME ""C:\Program Files\SplunkUniversalForwarder"""}
                Invoke-Command -ComputerName "$computer.tdm.local" { & cmd /c "C:\Windows\System32\msiexec.exe /i C:\Windows\Temp\Splunk\splunkforwarder-8.1.3-63079c59e632-x64-release.msi RECEIVING_INDEXER=""oracle.tdm.local:9997"" DEPLOYMENT_SERVER=""oracle.tdm.local:8089"" LAUNCHSPLUNK=0 SERVICESTARTTYPE=auto WINEVENTLOG_APP_ENABLE=1 WINEVENTLOG_SEC_ENABLE=1 WINEVENTLOG_SYS_ENABLE=1 WINEVENTLOG_FWD_ENABLE=1 WINEVENTLOG_SET_ENABLE=1 PERFMON=cpu,memory,network,diskspace  SET_ADMIN_USER=1 SPLUNKUSERNAME=admin SPLUNKPASSWORD=""Pa55w.rd"" AGREETOLICENSE=yes /quiet"}
                Invoke-Command -ComputerName "$computer.tdm.local" {Move-Item "C:\Windows\Temp\Splunk\inputs.conf" "C:\Program Files\SplunkUniversalForwarder\etc\system\local" -Force}
                Invoke-Command -ComputerName "$computer.tdm.local" {Restart-Service SplunkForwarder -Force}
                Remove-Item "\\$computer.tdm.local\c$\Windows\Temp\Splunk" -Force -Recurse -Confirm:$false
            }
        }
        catch {
            "$computer : $_" >> error.txt
        }            
        
    }
    else {
        "$computer" >> missed.txt
    }
}
