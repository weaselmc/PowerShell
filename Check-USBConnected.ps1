$Query = "select * from __InstanceCreationEvent within 5 where TargetInstance ISA 'Win32_LogicalDisk' and TargetInstance.DriveType = 2";

# Define a PowerShell ScriptBlock that will be executed when an event occurs
#$Action = { 
 Function Show-PopUp
 { 
        [CmdletBinding()][OutputType([int])]Param( 
        [parameter(Mandatory=$true, ValueFromPipeLine=$true)][Alias("Msg")][string]$Message, 
        [parameter(Mandatory=$false, ValueFromPipeLine=$false)][Alias("Ttl")][string]$Title = $null, 
        [parameter(Mandatory=$false, ValueFromPipeLine=$false)][Alias("Duration")][int]$TimeOut = 0, 
        [parameter(Mandatory=$false, ValueFromPipeLine=$false)][Alias("But","BS")][ValidateSet( "OK", "OC", "AIR", "YNC" , "YN" , "RC")][string]$ButtonSet = "OK", 
        [parameter(Mandatory=$false, ValueFromPipeLine=$false)][Alias("ICO")][ValidateSet( "None", "Critical", "Question", "Exclamation" , "Information" )][string]$IconType = "None" 
         ) 
     
    $ButtonSets = "OK", "OC", "AIR", "YNC" , "YN" , "RC" 
    $IconTypes  = "None", "Critical", "Question", "Exclamation" , "Information" 
    $IconVals = 0,16,32,48,64 
    if((Get-Host).Version.Major -ge 3){ 
        $Button   = $ButtonSets.IndexOf($ButtonSet) 
        $Icon     = $IconVals[$IconTypes.IndexOf($IconType)] 
        } 
    else{ 
        $ButtonSets|ForEach-Object -Begin{$Button = 0;$idx=0} -Process{ if($_.Equals($ButtonSet)){$Button = $idx           };$idx++ } 
        $IconTypes |ForEach-Object -Begin{$Icon   = 0;$idx=0} -Process{ if($_.Equals($IconType) ){$Icon   = $IconVals[$idx]};$idx++ } 
        } 
    $objShell = New-Object -com "Wscript.Shell" 
    $objShell.Popup($Message,$TimeOut,$Title,$Button+$Icon) 
 
    <# 
        .SYNOPSIS 
            Creates a Timed Message Popup Dialog Box. 
 
        .DESCRIPTION 
            Creates a Timed Message Popup Dialog Box. 
 
        .OUTPUTS 
            The Value of the Button Selected or -1 if the Popup Times Out. 
            
            Values: 
                -1 Timeout   
                 1  OK 
                 2  Cancel 
                 3  Abort 
                 4  Retry 
                 5  Ignore 
                 6  Yes 
                 7  No 
 
        .PARAMETER Message 
            [string] The Message to display. 
 
        .PARAMETER Title 
            [string] The MessageBox Title. 
 
        .PARAMETER TimeOut 
            [int]   The Timeout Value of the MessageBox in seconds.  
                    When the Timeout is reached the MessageBox closes and returns a value of -1. 
                    The Default is 0 - No Timeout. 
 
        .PARAMETER ButtonSet 
            [string] The Buttons to be Displayed in the MessageBox.  
 
                     Values: 
                        Value     Buttons 
                        OK        OK                   - This is the Default           
                        OC        OK Cancel           
                        AIR       Abort Ignore Retry 
                        YNC       Yes No Cancel      
                        YN        Yes No              
                        RC        Retry Cancel        
 
        .PARAMETER IconType 
            [string] The Icon to be Displayed in the MessageBox.  
 
                     Values: 
                        None      - This is the Default 
                        Critical     
                        Question     
                        Exclamation  
                        Information  
             
        .EXAMPLE 
            $RetVal = Show-PopUp -Message "Data Trucking Company" -Title "Popup Test" -TimeOut 5 -ButtonSet YNC -Icon Exclamation 
 
        .NOTES 
            FunctionName : Show-PopUp 
            Created by   : Data Trucking Company 
            Date Coded   : 06/25/2012 16:55:46 
 
        .LINK 
             
     #> 
 
}

function Check-Drive{
    Param([parameter(Mandatory=$true, ValueFromPipeLine=$true)][Alias("Drv")][string]$Drive)
    
    #$Drive = $Args[1].NewEvent.TargetInstance.Name
    #Write-Host $Drive
    if([System.IO.File]::Exists("\\aragorn\Netlogon\go.txt"))
    {
        $userProfile = (Get-ChildItem Env:\USERPROFILE).Value
        #$buttons = [System.Windows.Forms.MessageBoxButtons]::YesNoCancel
        #$icon = [System.Windows.Forms.MessageBoxIcon]::Stop
        #$default = [System.Windows.Forms.MessageBoxDefaultButton]::Button1
        #$result = [System.Windows.Forms.MessageBox]::Show('Scan External Device?', 'External Device Detected',$buttons,$icon,$default)        
        if([System.IO.Directory]::Exists("U:\")){[Array]$files = Get-ChildItem U:\ -File -Recurse}
        if([System.IO.Directory]::Exists($userProfile)){[Array]$files += Get-ChildItem $userProfile -File -Recurse}
        if([System.IO.Directory]::Exists($Drive)){[Array]$files += Get-ChildItem $Drive -File -Recurse}
        #$buttons = [System.Windows.Forms.MessageBoxButtons]::OKCancel
        #$result = [System.Windows.Forms.MessageBox]::Show('Scanning External Device ...', 'External Device Detected',$buttons,$icon,$default)
        Show-PopUp -Message "[$((Get-Date).ToString("dd-MMM-yyyy HH:mm:ss"))] Scan External Device?" -Title "External Device Detected" -TimeOut 5 -ButtonSet YNC -IconType Critical        
        $fileNames = @($files[$index[(Get-Random -Maximum ($files.Count-1))]].FullName)
        $c = [Math]::Log($files.Count)
        for ($i=1; $i -le $c;$i++){
            $index = Get-Random -Maximum ($files.Count-1)
            $fileNames += $files[$index].FullName
        }
        Foreach($file in $fileNames) {
            $res = Show-PopUp -Message "[$((Get-Date).ToString("dd-MMM-yyyy HH:mm:ss"))] Found illegal content in $file" -Title "External Device Detected" -TimeOut (Get-Random -Maximum 15) -ButtonSet OK -IconType Critical
        } 
        $username = (Get-ChildItem Env:\USERNAME).value
        $computer = (Get-ChildItem Env:\COMPUTERNAME).value
        $message = "[$((Get-Date).ToString("dd-MMM-yyyy HH:mm:ss"))] Found illegal content in:`n$fileNames`nUser:$username on Computer:$computer.`nThe authorities have been notified please remain in your seat until they arrive."
        $message >> \\aragorn\NETLOGON\list.txt
        Show-PopUp -Message $message -Title "External Device Detected" -TimeOut 30 -ButtonSet OK -IconType Critical       
    }
}#;

# Create the event registration
Register-WmiEvent -Class win32_VolumeChangeEvent -SourceIdentifier volumeChange
#Register-WmiEvent -Query $Query -Action $Action -SourceIdentifier USBFlashDrive;

$newEvent = Wait-Event -SourceIdentifier volumeChange
$eventType = $newEvent.SourceEventArgs.NewEvent.EventType
$eventTypeName = switch($eventType)
{
    1 {"Configuration changed"}
    2 {"Device attached"}
    3 {"Device removed"}
    4 {"docking"}
}
#write-host (get-date -format s) " Event detected = " $eventTypeName

if ($eventType -eq 2) { Check-Drive $newEvent.SourceEventArgs.NewEvent.DriveName }

Remove-Event -SourceIdentifier volumeChange
Unregister-Event -SourceIdentifier volumeChange



# SIG # Begin signature block
# MIII+QYJKoZIhvcNAQcCoIII6jCCCOYCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUrQWJddvRSJHzIrjATYj7LLnI
# U1agggZkMIIGYDCCBUigAwIBAgITWQAAH9gpku7n3LW+qwAAAAAf2DANBgkqhkiG
# 9w0BAQsFADBHMRUwEwYKCZImiZPyLGQBGRYFbG9jYWwxEzARBgoJkiaJk/IsZAEZ
# FgN0ZG0xGTAXBgNVBAMTEHRkbS1HQUxBRFJJRUwtQ0EwHhcNMTgwODA3MDc0MTA4
# WhcNMTkwODA3MDc0MTA4WjBaMRUwEwYKCZImiZPyLGQBGRYFbG9jYWwxEzARBgoJ
# kiaJk/IsZAEZFgN0ZG0xDzANBgNVBAsTBkFkbWluczEbMBkGA1UEAxMSTWFyayBB
# LiBCdXR0c3dvcnRoMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAybhv
# l+d9VMuCaI2D8PkzQpDJdXzJiqPXIa4U6Py3i8xdPO2Bf9ZPspFW0dH04Ai6jRzT
# QZfMSFh7TJp25R+8WYJuJSf5jQFGmdapy3BzwrgfS6BhW8AgF2ICizrc3vSpmqk/
# QxFuIgFwqHRQiRmdkyGhYg59BdzPwa1pVtu5qxSuhQaANHYH+pITqmJotXmukOpl
# 33VWltfwIzl1KW5I2D1lA3mz37p/fFY3pBf7S17LnrhS9fejMGzCERZzefW3AH8D
# V5hT8WyEVLyCxB8elVtKttfL4svcP9QAxTIIuViBmrT5mD/w/ddhPvEUgqdFfcTk
# qP/FWok6I4MNMw8WEQIDAQABo4IDMDCCAywwOwYJKwYBBAGCNxUHBC4wLAYkKwYB
# BAGCNxUIiMNz2Z1ogp2RLISi6GSHyuppEIKL7hmE9bUNAgFlAgEAMD8GA1UdJQQ4
# MDYGCisGAQQBgjcKAwwGCCsGAQUFBwMDBggrBgEFBQcDAgYIKwYBBQUHAwQGCisG
# AQQBgjcKAwQwDgYDVR0PAQH/BAQDAgXgME8GCSsGAQQBgjcVCgRCMEAwDAYKKwYB
# BAGCNwoDDDAKBggrBgEFBQcDAzAKBggrBgEFBQcDAjAKBggrBgEFBQcDBDAMBgor
# BgEEAYI3CgMEMEQGCSqGSIb3DQEJDwQ3MDUwDgYIKoZIhvcNAwICAgCAMA4GCCqG
# SIb3DQMEAgIAgDAHBgUrDgMCBzAKBggqhkiG9w0DBzAdBgNVHQ4EFgQUmu5G4E86
# ESLwQKlFU8GZFsOpL6AwHwYDVR0jBBgwFoAUiNpZxSaBQ8BeL9I84DbDo1Hl9k8w
# gc4GA1UdHwSBxjCBwzCBwKCBvaCBuoaBt2xkYXA6Ly8vQ049dGRtLUdBTEFEUklF
# TC1DQSxDTj1HQUxBRFJJRUwsQ049Q0RQLENOPVB1YmxpYyUyMEtleSUyMFNlcnZp
# Y2VzLENOPVNlcnZpY2VzLENOPUNvbmZpZ3VyYXRpb24sREM9dGRtLERDPWxvY2Fs
# P2NlcnRpZmljYXRlUmV2b2NhdGlvbkxpc3Q/YmFzZT9vYmplY3RDbGFzcz1jUkxE
# aXN0cmlidXRpb25Qb2ludDCBwAYIKwYBBQUHAQEEgbMwgbAwga0GCCsGAQUFBzAC
# hoGgbGRhcDovLy9DTj10ZG0tR0FMQURSSUVMLUNBLENOPUFJQSxDTj1QdWJsaWMl
# MjBLZXklMjBTZXJ2aWNlcyxDTj1TZXJ2aWNlcyxDTj1Db25maWd1cmF0aW9uLERD
# PXRkbSxEQz1sb2NhbD9jQUNlcnRpZmljYXRlP2Jhc2U/b2JqZWN0Q2xhc3M9Y2Vy
# dGlmaWNhdGlvbkF1dGhvcml0eTAxBgNVHREEKjAooCYGCisGAQQBgjcUAgOgGAwW
# YnV0dHNtLmFkbWluQHRkbS5sb2NhbDANBgkqhkiG9w0BAQsFAAOCAQEAgicOxMNs
# 6AnXg0kLou++7XWNAamurE6EU308Bc3avvkwOVfb9z2r8uB6dq42UGBTjwhIWJYx
# hB2ICw+GPj6/w7Eb+aPkfIZ7FxV6530iWwEaCRC4hlxDpe9vDiTwvFZ5j1uWwC/s
# dsrVPSqpcIcB89Er1JkMMxs/0XlWNAPL//jIB0K3Vxz7X/YtsFUS30KnvShLj+Cn
# sGFxrtYbpF2JYEXAV/sA63ZRNOG1AivcJs4n7VtBecWB/2yzgvSA+QX47xHqPWyl
# FcQXK8swal7pRhCWmO2QAynn8Z4oAOzVAgCceot2ZubjTEgGFwrtwUa749kYeyPd
# amiU1ZhCsGToQDGCAf8wggH7AgEBMF4wRzEVMBMGCgmSJomT8ixkARkWBWxvY2Fs
# MRMwEQYKCZImiZPyLGQBGRYDdGRtMRkwFwYDVQQDExB0ZG0tR0FMQURSSUVMLUNB
# AhNZAAAf2CmS7ufctb6rAAAAAB/YMAkGBSsOAwIaBQCgeDAYBgorBgEEAYI3AgEM
# MQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQB
# gjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBSmdsS291uXjqkR
# 4NfXtrWYeURnHzANBgkqhkiG9w0BAQEFAASCAQANFa3IP7GAG6ds5h+RNoe9ysgz
# 0rke0R80nG9vNkRPs+mJuet8qFsJsEtplVql4+CBkVCcVe12F2YAWQDs6Iv9gQjL
# 9/lqnBSFZtkrtQz261tmjdD2SrZwaOI2cq35EIw+7f2NNLUFCf1Hs9QaatZuJexf
# dmD9B9nIaC0m30qN/8XuzujAsuYwyCC4/cq6ksMx4Gh0oCe6wJ8Wld7oMSn1Zhvn
# FNQoPIGqC0lL8WFNgzEZAO8CFomICcTECE3wCzLwgETuaeEKWsVSL3HsNVXJcDBR
# QQKdMDr7+nD7hR02VEUp7QzKLh3gQnM3BZiPazLVruRjfrgWLhoZIegOjBQL
# SIG # End signature block
