for($i=31; $i -le 50;$i++){
    if($i -le 9)
    {
        $s = "00" + $i
    }
    elseif ($i -le 99)
    {
        $s = "0" + $i
    }
    else
    {
        $s = $i
    }
    $Server = "HD$s"
    $vm = New-VM -Name $Server -MemoryStartupBytes 4096MB -BootDevice NetworkAdapter -NewVHDSizeBytes 64GB -SwitchName "20G-TDM Virtual Switch" -Generation 2 -Path C:\ClusterStorage\Volume1\StudentVMs -NewVHDPath "C:\ClusterStorage\Volume1\StudentVMs\$Server\Virtual Hard Disks\$Server.vhdx"
    $vm | set-vm -DynamicMemory -MemoryMinimumBytes 512MB -MemoryMaximumBytes 4GB
    Set-VMNetworkAdapterVlan (Get-VMNetworkAdapter $vm) -Access -VlanId 10
    #Start-VM $vm
    Write-Host -ForegroundColor Cyan "$Server created."
}