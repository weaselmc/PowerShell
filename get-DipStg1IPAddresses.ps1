function Get-StudentAdvDipStg1IP
{
    param(
         [string]$User)

    $ClientIP=""
    $ServerIP=""
    $vms = get-clusterResource -Cluster admin-hci-cluster
    $ClientIP = ($vms | ? {$_.Name -like "Virtual Machine RBFE-$User-W11"} |%{ Hyper-V\Get-VM -Name $_.OwnerGroup -ComputerName $_.OwnerNode} | Get-VMNetworkAdapter)[1].IPAddresses[0]
    
    $ServerIP = ($vms | ? {$_.Name -like "Virtual Machine RBFE-$User-Server"} | % { Hyper-V\Get-VM -Name $_.OwnerGroup -ComputerName $_.OwnerNode} | Get-VMNetworkAdapter)[1].IPAddresses[0]
    
    Write-Host "RBFE-$User-W11:$ClientIP"
    Write-Host "RBFE-$User-Server:$ServerIP"

}

$users = $vms | ? {$_.Name -like "Virtual Machine RBFE-*-w11"} |% {($_.OwnerGroup).substring(5,6)}

Foreach ($user in $users)
{
    Get-StudentAdvDipStg1IP -User $user
}

