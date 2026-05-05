Param(
    [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true, ValueFromPipeline=$true)]
    [String]$User,
    [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true, ValueFromPipeline=$true)]
    [Int]$Vlan
)

$VMs = Get-ChildItem "C:\ClusterStorage\Data\Export"

foreach ($VM in $VMs)
{
    $Name = $VM.Name.split("-")
    $VMName = "$($Name[0])-$($User)-$($Name[1])"

    $Path = "C:\ClusterStorage\StudentsVMs\$VMName"  
    Copy-Item "$($VM.FullName)\" -Destination $Path -Recurse
    $VMcx = Get-Item "$($Path)\Virtual Machines\*.vmcx"
    $Report = Compare-VM -Path $VMcx -Copy -GenerateNewId -VhdDestinationPath "$($Path)\Virtual Hard Disks"    
    Rename-VM $Report.VM -NewName $VMName
    foreach ($VMHDD in $Report.Incompatibilities)
    {
        $VMHDDPath = $VMHDD.Source.Path -ireplace [regex]::Escape("hyper-v\"), "$($User)-"
        $VMHDD.Source | Set-VMHardDiskDrive -Path $VMHDDPath            
    }
    if($VMName.Contains("Client"))
    {
        Set-VMNetworkAdapterVlan -VMNetworkAdapter $Report.VM.NetworkAdapters[0] -VlanId $VLan -Access
        Set-VMMemory -VM $Report.VM -DynamicMemoryEnabled $true -StartupBytes 4096Mb -MinimumBytes 1024Mb -MaximumBytes 8192Mb
    }
    elseif($VMName.Contains("N1"))
    {
        <# Action when all if and elseif conditions are false #>
        Set-VMNetworkAdapterVlan -VMNetworkAdapter $Report.VM.NetworkAdapters[0] -VlanId $VLan -Access
        Set-VMNetworkAdapterVlan -VMNetworkAdapter $Report.VM.NetworkAdapters[1] -VlanId ($VLan+1) -Access
        Set-VMNetworkAdapterVlan -VMNetworkAdapter $Report.VM.NetworkAdapters[2] -VlanId ($VLan+2) -Access
        Set-VMMemory -VM $Report.VM -DynamicMemoryEnabled $true -StartupBytes 16384Mb -MinimumBytes 8192Mb -MaximumBytes 32768Mb
    }
    elseif($VMName.Contains("N2"))
    {
        <# Action when all if and elseif conditions are false #>
        Set-VMNetworkAdapterVlan -VMNetworkAdapter $Report.VM.NetworkAdapters[1] -VlanId $VLan -Access
        Set-VMNetworkAdapterVlan -VMNetworkAdapter $Report.VM.NetworkAdapters[2] -VlanId ($VLan+1) -Access
        Set-VMNetworkAdapterVlan -VMNetworkAdapter $Report.VM.NetworkAdapters[3] -VlanId ($VLan+2) -Access
        Set-VMMemory -VM $Report.VM -DynamicMemoryEnabled $true -StartupBytes 16384Mb -MinimumBytes 8192Mb -MaximumBytes 32768Mb
    }
    Import-VM -CompatibilityReport $Report
    Remove-Item "$($Path)\Virtual Hard Disks\*.vhdx"    
}

if((Get-VM "*$user*" | Get-VMHardDiskDrive | Where-Object Path -notlike "*_*").Count -eq 0)
{
    Get-VM "*$user*Client" | Start-VM
    Start-Sleep -Seconds 5
    Get-VM "*$user*N*" | Start-VM
}

$ClientIP = (Get-VMNetworkAdapter -VMName "RBFE-$User-Client")[1].IPAddresses[0]
while([string]::IsNullOrEmpty($ClientIP) -and $ClientIP[1].IPAddresses[0] -notlike "172.20.*")
{
    Start-Sleep -Seconds 1
    $ClientIP = (Get-VMNetworkAdapter -VMName "RBFE-$User-Client")[1].IPAddresses[0]
}

Start-Sleep -Seconds 5

$lc = New-Object -typename System.Management.Automation.PSCredential -argumentlist "rbfe\localadmin", (ConvertTo-SecureString "Pa55w.rd" -AsPlainText -Force)
$PfSenseVM = Invoke-Command -VMName "RBFE-$User-N2" -Credential $lc -ScriptBlock{Get-VM RBFE-PfS}
While($PfSenseVM.State -ne "Running")
{
    Start-Sleep -Seconds 1
    $PfSenseVM = Invoke-Command -VMName "RBFE-$User-N2" -Credential $lc -ScriptBlock{Get-VM RBFE-PfS}
}
Invoke-Command -VMName "RBFE-$User-N2" -Credential $lc -ScriptBlock{Stop-VM RBFE-PfS}
Invoke-Command -VMName "RBFE-$User-N2" -Credential $lc -args $Vlan -ScriptBlock{Param($v) (Get-VMNetworkAdapter -VMName RBFE-PfS)[1]|Set-VMNetworkAdapter -StaticMacAddress "00155DDB$('{0:d4}' -f $v)"}
Invoke-Command -VMName "RBFE-$User-N2" -Credential $lc -ScriptBlock{Start-VM RBFE-PfS}
$PfSenseIP = Invoke-Command -VMName "RBFE-$User-N2" -Credential $lc -ScriptBlock{(Get-VMNetworkAdapter -VMName RBFE-PfS)[1].IPAddresses[0]}
while([string]::IsNullOrEmpty($PfSenseIP) -and $PfSenseIP[1].IPAddresses[0] -notlike "123.103.219*") 
{
    Start-Sleep -Seconds 1
    $PfSenseIP = Invoke-Command -VMName "RBFE-$User-N2" -Credential $lc -ScriptBlock{(Get-VMNetworkAdapter -VMName RBFE-PfS)[1].IPAddresses[0]}
}
Write-Host "TDM IP: $ClientIP"
Write-Host "External IP: $PfSenseIP"
"$User, $ClientIP, $PfSenseIP" | Out-File -FilePath .\AdvDipIPs.csv -Append -Confirm:$false

Get-VM *$User* | Add-ClusterVirtualMachineRole