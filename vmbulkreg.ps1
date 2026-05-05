
$course = "20331"
$path = "C:\Program Files\Microsoft Learning\$course"
Get-ChildItem $path -Recurse -Filter "Virtual Machines" | %{write-host "VM Name: "$_.Fullname; Get-ChildItem $_.FullName -Filter *.xml} | %{Compare-VM $_.FullName -Register} | %{$_.Incompatibilities.message; write-host}