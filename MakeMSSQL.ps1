#$filepath = Get-ChildItem -Path $dst | sort name -Descending
#if($filepath -eq $null)
#{
#    $dst = $dst + "\MSSQL001"
#    }
#else
for($c=52; $c -lt 60;$c++)
{
    $src = "C:\ClusterStorage\Volume1\Source\SQLAWServer"
    #$dst = "C:\ClusterStorage\Volume1\StudentVMs"
    #$c = 1 + $filepath[0].Name.Substring(5)
    if($c -le 9)
    {
        $cs = "00" + $c
    }
    elseif ($c -le 99)
    {
        $cs = "0" + $c
    }
    else
    {
        $cs = $c
    }
    $dst = "C:\ClusterStorage\Volume1\StudentVMs\MSSQLServer$cs\"
    Write-Host -ForegroundColor Cyan "Copying: $src to $dst"
    Copy-Item $src $dst -Recurse
    $vhdPath = $dst + "Virtual Hard Disks"
    $vmPath = $dst + "Virtual Machines"
    $cpPath = $dst + "Snapshots"
    $vmcxpath = Get-ChildItem $dst -Recurse -Filter *.vmcx
    Write-Host -ForegroundColor Cyan "Importing:$($vmcxPath.FullName)"
    $vm = Import-VM -Path $vmcxPath.FullName -GenerateNewId -Copy -VhdDestinationPath $vhdPath -VirtualMachinePath $vmPath -SmartPagingFilePath $vmPath -SnapshotFilePath $cpPath
    $vm | Set-VM -NewVMName $("MSSQLServer" + $cs)
    #Start-VM $vm
}
