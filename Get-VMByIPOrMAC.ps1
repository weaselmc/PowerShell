param( $MACAddress, $IPAddress, $Cluster = "TheShire" )


if(![string]::IsNullOrEmpty($MACAddress)){
    Get-ClusterResource -Cluster $Cluster  | ? ResourceType -eq "Virtual Machine" | get-vm | Get-VMNetworkAdapter | ? MacAddress -eq $MACAddress
    }
elseif (![string]::IsNullOrEmpty($IPAddress)){
    Get-ClusterResource -Cluster $Cluster | ? ResourceType -eq "Virtual Machine" | get-vm | Get-VMNetworkAdapter | ? MacAddress -eq $IPAddress
    }