[CmdletBinding()]
param(
    [Parameter()]
    [string]$ClusterName
)

$ClusterParams = @{}
if (-not [string]::IsNullOrWhiteSpace($ClusterName)) {
    $ClusterParams['Cluster'] = $ClusterName
}

$VMs = @(
    Get-ClusterGroup @ClusterParams -ErrorAction Stop |
        Where-Object {
            $_.GroupType -eq 'VirtualMachine' -and
            $_.Name -like '*RBFE25-N*'
        }
)

if ($VMs.Count -eq 0) {
    Write-Output "No matching clustered VMs found."
    return
}

$Results = foreach ($VM in $VMs) {
    $VMName = $VM.Name
    $HostNode = $VM.OwnerNode

    try {
        $Adapters = @(
            Get-VMNetworkAdapter -VMName $VMName -ComputerName $HostNode -ErrorAction Stop |
                Where-Object Name -eq "NIC-3"
        )
    }
    catch {
        [PSCustomObject]@{
            VMName             = $VMName
            Host               = $HostNode
            Adapter            = "NIC-3"
            MacAddressSpoofing = $null
            Status             = "Query failed: $($_.Exception.Message)"
        }
        continue
    }

    if ($Adapters.Count -eq 0) {
        [PSCustomObject]@{
            VMName             = $VMName
            Host               = $HostNode
            Adapter            = "NIC-3"
            MacAddressSpoofing = $null
            Status             = "NIC-3 Not Found"
        }
        continue
    }

    foreach ($Adapter in $Adapters) {
        [PSCustomObject]@{
            VMName             = $VMName
            Host               = $HostNode
            Adapter            = $Adapter.Name
            MacAddressSpoofing = $Adapter.MacAddressSpoofing
            Status             = "OK"
        }
    }
}

$Results | Format-Table -AutoSize