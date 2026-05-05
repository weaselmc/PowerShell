Function New-20744VM{
<#
.SYNOPSIS
Creates an MSSQLServer for the Programming Classes

.DESCRIPTION
Creates a VM with MSSSQL Server and Admin tools in a cluster. Adds remote desktop access. Can have IIS added to support REST or WCF server apps.

.PARAMETER Server
Server name for VM.

.PARAMETER User
User for RDP file creation.

.PARAMETER Group
Group user is in for RDP file creation. Default is AB51 (Adv Dip Net Sec Cyber)

.PARAMETER

.EXAMPLE
New-MSSQLVM -User Student

#>
    Param(           
        [Parameter (Mandatory=$true, ValueFromPipelineByPropertyName=$true, ValueFromPipeline=$true)]
        [String]$User,
        [String]$Group = "AB51",
        #[String]$AdminUser = "tdm\baraba",
        [String]$vcadmin = "administrator@vsphere.local",
        [string]$RDPFilePath = "\\GONDOR.TDM.LOCAL\Students$"
        )

        Begin{
             #$secpasswd = ConvertTo-SecureString ???  -AsPlainText -Force             
             #$DomainCredential = New-Object System.Management.Automation.PSCredential ($AdminUser, (Read-Host "Enter $AdminUser password" -AsSecureString))             
             $VCcred = New-Object System.Management.Automation.PSCredential ($vcadmin, (Read-Host "Enter $vcAdmin password" -AsSecureString))             
        }
        process{
            $scriptBlock = 
            {
                param($User, $Group, $VCcred)

                if ((Get-Module VMware.PowerCLI) -eq $null){
                    Import-Module VMware.PowerCLI}
                Connect-VIServer "vcenter.tdmadmin.local" -Credential $VCcred
            
                $Server = "20744C-LON-HOST1-$User"
                $Username = "TDM\$User"

                try { 
                    $vm = get-vm $Server -ErrorAction Stop
                    write-host -ForegroundColor Green "Server $server already exists."                   
                } 
                catch {
                    Write-Host "Creating $Server" -ForegroundColor Yellow
                    New-VM -Template 20744C-LON-HOST1 -Name $Server -Datastore iSCSI_VMF1 -Location Networking -ResourcePool Resources                    
                    Start-VM $Server
                    while ([string]::IsNullOrEmpty($vmIP) -or $vmIP -notlike "172.20*") {$vmIP = (Get-VMGuest $Server).IPAddress[0]}
                    #create rdpfile
                    New-VIPermission -Entity $Server -Principal $Username -Role "VirtualMachineConsoleUser" -Propagate $true
                    Write-Host "Creating $RDPFilePath\$Group\$User\$Server.rdp" -ForegroundColor Yellow 
                    New-RDPFile -Server $Server -Username $User -Path "$RDPFilePath\$Group\$User" -IP $vmIP                    
                }
            }

            Start-Job -ScriptBlock $scriptBlock -ArgumentList @($User, $Group, $DomainCredential,$VCcred) -Name "Create-20744C-LON-HOST1-$User"
         
        }
}
