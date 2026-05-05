$spec = New-Object VMware.Vim.VirtualMachineConfigSpec
$spec.NestedHVEnabled = $true

$vms = VMware.VimAutomation.Core\Get-VM RBFE-CS*

foReach($vm in $vms)
{
    VMware.VimAutomation.Core\Stop-VM $vm -Confirm:$false
    VMware.VimAutomation.Core\Set-VM -VM $vm -MemoryGB 16 -CoresPerSocket 4 -NumCpu 8 -Confirm:$false
    $vm.ExtensionData.ReconfigVM($spec)
    VMware.VimAutomation.Core\Start-VM $vm -RunAsync -Confirm:$false
}