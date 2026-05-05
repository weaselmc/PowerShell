
    [String]$User = "HICKIL"
    [String]$Group = "AB51"    
    [String]$vcadmin = "administrator@vsphere.local"
    [string]$RDPFilePath = "\\GONDOR.TDM.LOCAL\Students$"
    $VCcred = New-Object System.Management.Automation.PSCredential ($vcadmin, (Read-Host "Enter $vcAdmin password" -AsSecureString))

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