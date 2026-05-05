function Respawn-RBFEStg2{
    Param(           
        [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true, ValueFromPipeline=$true)]   
        [string]$StudentvApp,
        [string]$Datastore = "Net_Datastore",
        [PSCredential]$VCcred
    )

    if ($null -eq (Get-Module VMware.PowerCLI)){
        Import-Module VMware.PowerCLI
    }

    if ($global:DefaultVIServers.count -eq 0){
        if($null -eq $VCcred){$VCcred = Get-Credential "administrator@tdmadmin.vslocal" }
        Connect-VIServer "vcenter.tdmadmin.local" -Credential $VCcred
    }

    $vms = get-vm -Location BUTTSM-RBFE-Stg2-vApp | Where-Object Name -ne RBFE-OpenWRT
    [int]$vlan = ((Get-VM RBFE-OpenWRT -Location $StudentvApp| Get-NetworkAdapter).NetworkName)[0].substring(4,3)
    $lvms = Get-VM -Location $StudentvApp | Where-Object Name -ne RBFE-OpenWRT
    $lvms | Stop-VM -Confirm:$false
    $lvms | Remove-vm -DeletePermanently -Confirm:$false
    foreach ($vm in $vms) {
        New-VM -VM $vm -Name $vm.Name -ResourcePool $StudentvApp -DiskStorageFormat Thin -Datastore $Datastore   
    }
    $net = Get-VM -Location  $StudentvApp | Get-NetworkAdapter
    $net | Where-Object NetworkName -eq "Vlan280" | Set-NetworkAdapter -NetworkName "Vlan$($vlan)DPortGroup" -Confirm:$false
    $net | Where-Object NetworkName -eq "Vlan281" | Set-NetworkAdapter -NetworkName "Vlan$($vlan+1)DPortGroup" -Confirm:$false
    $net | Where-Object NetworkName -eq "Vlan282" | Set-NetworkAdapter -NetworkName "Vlan$($vlan+2)DPortGroup" -Confirm:$false
    $net | Where-Object NetworkName -eq "TDM" | Set-NetworkAdapter -NetworkName "dpgTDM" -Confirm:$false
    $net | Where-Object NetworkName -eq "External" | Set-NetworkAdapter -NetworkName "dpgExternal" -Confirm:$false
}