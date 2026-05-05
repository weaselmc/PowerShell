$drives = Get-ClusterResource *RBFE-* -Cluster admin-hci-cluster |? ResourceType -eq "Virtual Machine" | get-vm |Get-VMHardDiskDrive | ? Path -like "C:\ClusterStorage\Data\VHDs\RBFE-*"
foreach($drive in $drives)
{
    $VMPath = "C:\ClusterStorage\StudentVMs\$($drive.VMName)\Virtual Hard Disks\"
    $olddrive = ($drive.Path.Split("\") |select -Last 1).split(".")[0]    
    $newdrivepath = "$vmpath$($olddrive)_*"
    $newdrive = Invoke-Command -ComputerName admin-hci-n3 -ScriptBlock {param($p) get-item $p} -args $newdrivepath
    Set-VMHardDiskDrive $drive -Path $newdrive.FullName
}