Param(
    [string]$CommonName,
    [string]$OrganizationalUnit="IT", 
    [string]$Organization="NMT",
    [string]$City="Joondalup",
    [string]$State="WA",
    [string]$Country="AU"
)

# Define the certificate request parameters
$certRequestParams = @"
[NewRequest]
Subject = "CN=$CommonName, OU=$OrganizationalUnit, O=$Organization, L=$City, S=$State, C=$Country"
FriendlyName = $CommonName
KeySpec = 1
KeyLength = 2048
Exportable = TRUE
MachineKeySet = TRUE
SMIME = FALSE
PrivateKeyArchive = FALSE
UserProtected = FALSE
UseExistingKeySet = FALSE
ProviderName = "Microsoft RSA SChannel Cryptographic Provider"
ProviderType = 12
RequestType = PKCS10
KeyUsage = 0xa0

[EnhancedKeyUsageExtension]
OID = 1.3.6.1.5.5.7.3.1 ; Server Authentication

[Extensions]
2.5.29.17 = "{text}"
_continue_ = "dns=$CommonName"
"@

# Save the certificate request parameters to a file
$certRequestFile = "CertRequest.inf"
Set-Content -Path $certRequestFile -Value $certRequestParams

# Generate the certificate request
certreq -new $certRequestFile "CertRequest.req"