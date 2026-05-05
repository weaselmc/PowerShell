$UserCredential = Get-Credential "TDM\buttsm"
$hs = import-csv .\HelpDeskOut.csv
Foreach($slot in $hs) {
    $subject = "$($slot.Name) on Help Desk duty"
    $body = "You ($($slot.Name)) have been scheduled for Help Desk duty.`r`n$EmailBody"
    $Attendees = "mark.buttsworth@nmtafe.wa.edu.au","gerhard.labuschagne@nmtafe.wa.edu.au", $slot.EmailAddress
    New-HelpDeskAppointment -Credentials $UserCredential -Subject $subject -Body $body -ReqAttendee $Attendees -MeetingStart (get-date $slot.start).Date -MeetingDuration 240
    Write-Host -ForegroundColor Green "$subject -> Sent for $($start.ToLongDateString()) $($start.ToShortTimeString())"
}