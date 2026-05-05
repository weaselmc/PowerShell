$VApps = Get-VApp -Location  NetDipStage1
foreach($VApp in $VApps){
    $vms = Get-VM -Location $VApp
    foreach($vm in $vms){
        $vmas = Get-NetworkAdapter $vm | ? NetworkName -like "VLan*" | Sort-Object
        foreach($vma in $vmas){
                Write-Host "$($VApp.Name) $($vm.Name) $($vma.NetworkName)"
                $new = $vma.NetworkName.ToCharArray()
                $new[4] = '3'
                $new = $new -join ""
                Write-Host -ForegroundColor Green "$($VApp.Name) $($vm.Name) $new"
                Set-NetworkAdapter $vma -NetworkName $new -Confirm:$false
        }
    }
}