[String]$AdminUser = "tdm\baraba"
[String]$vcadmin = "administrator@vsphere.local"
[string]$RDPFilePath = "\\GONDOR.TDM.LOCAL\Students$"
[String]$Group = "BEH6"
[String]$User = "WILKIJ"

#$DomainCredential = [System.Management.Automation.PSCredential]::new($AdminUser, (Read-Host "Enter $AdminUser password" -AsSecureString))
#$VCcred =[System.Management.Automation.PSCredential]::new($vcadmin, (Read-Host "Enter $vcAdmin password" -AsSecureString)) 

#Import-Module VMware.PowerCLI
#Connect-VIServer "vcenter.tdmadmin.local" -Credential $VCcred
$Credential = [System.Management.Automation.PSCredential]::new("administrator",(ConvertTo-SecureString "!G0LLum!" -AsPlainText))

$vms = get-vm "*$user"

foreach($vm in $vms){    
    if($vm.Name -notlike "*WRT*"){
        $vmIP = Get-VMGuest $vm | select -ExpandProperty IPAddress | ? {$_ -like "172.20.*"}
        Write-Host "Resetting local admin psssword for $vm($vmIP)" -ForegroundColor Yellow
        Invoke-Command $vmIP -Credential $Credential -ScriptBlock {Set-LocalUser "Administrator" -Password (ConvertTo-SecureString "Pa55w.rd" -AsPlainText)}
    }
}