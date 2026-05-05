Function Show-PopUp{ 
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

# Define a WMI event query, that looks for new instances of Win32_LogicalDisk where DriveType is "2"
# http://msdn.microsoft.com/en-us/library/aa394173(v=vs.85).aspx
$Query = "select * from __InstanceCreationEvent within 5 where TargetInstance ISA 'Win32_LogicalDisk' and TargetInstance.DriveType = 2";

# Define a PowerShell ScriptBlock that will be executed when an event occurs
$Action = { 
    if([System.IO.File]::Exists("\\aragorn\Netlogon\go.txt"))
    {
        $event
    }

};

# Create the event registration
Register-WmiEvent -Query $Query -Action $Action -SourceIdentifier USBFlashDrive;

#Requires -version 2.0
Register-WmiEvent -Class win32_VolumeChangeEvent -SourceIdentifier volumeChange
write-host (get-date -format s) " Beginning script..."
do{
$newEvent = Wait-Event -SourceIdentifier volumeChange
$eventType = $newEvent.SourceEventArgs.NewEvent.EventType
$eventTypeName = switch($eventType)
{
    1 {"Configuration changed"}
    2 {"Device arrival"}
    3 {"Device removal"}
    4 {"docking"}
}
write-host (get-date -format s) " Event detected = " $eventTypeName

if ($eventType -eq 2)
{
    $driveLetter = $newEvent.SourceEventArgs.NewEvent.DriveName
    $driveLabel = ([wmi]"Win32_LogicalDisk='$driveLetter'").VolumeName
    write-host (get-date -format s) " Drive name = " $driveLetter
    write-host (get-date -format s) " Drive label = " $driveLabel
    # Execute process if drive matches specified condition(s)
    if ($driveLetter -eq 'Z:' -and $driveLabel -eq 'Mirror')
    {
        write-host (get-date -format s) " Starting task in 3 seconds..."
        start-sleep -seconds 3
        start-process "Z:\sync.bat"
    }
}

Remove-Event -SourceIdentifier volumeChange
} while (1-eq1) #Loop until next event
Unregister-Event -SourceIdentifier volumeChange