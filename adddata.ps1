$servers = "DipNetS2FA002","DipNetS2FA003"
$VMServerPath = "C:\ClusterStorage\Volume5\"
foreach($vm in $servers)
{    
    #New-VHD "$VMServerPath$vm\Virtual Hard Disks\Data_1.vhdx" -Dynamic -SizeBytes 64GB
    #New-VHD "$VMServerPath$vm\Virtual Hard Disks\Data_2.vhdx" -Dynamic -SizeBytes 64GB
    #New-VHD "$VMServerPath$vm\Virtual Hard Disks\Data_3.vhdx" -Dynamic -SizeBytes 64GB
    "$VMServerPath$vm\Virtual Hard Disks\Data_1.vhdx"
    Add-VMHardDiskDrive -VMName $vm -Path "$VMServerPath$vm\Virtual Hard Disks\Data_1.vhdx" -ControllerType SCSI -ControllerNumber 0 -ControllerLocation 1
    Add-VMHardDiskDrive -VMName $vm -Path "$VMServerPath$vm\Virtual Hard Disks\Data_2.vhdx" -ControllerType SCSI -ControllerNumber 0 -ControllerLocation 2
    Add-VMHardDiskDrive -VMName $vm -Path "$VMServerPath$vm\Virtual Hard Disks\Data_3.vhdx" -ControllerType SCSI -ControllerNumber 0 -ControllerLocation 3
}