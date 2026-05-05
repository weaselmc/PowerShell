
<# 
.SYNOPSIS
    Creates an Azure subscription with display name:
      TDM-2025-S2-<username>-<id>
    and adds a $100 monthly budget with an 80% alert.

.PARAMETERS
    -Username              Short username for the subscription display name.
    -Id                    Identifier to include in the display name.
    -BillingScope          Billing scope string for your agreement type:
                             MCA: /billingAccounts/{billingAccountName}/billingProfiles/{billingProfileName}/invoiceSections/{invoiceSectionName}
                             EA : /billingAccounts/{billingAccountName}/enrollmentAccounts/{enrollmentAccountName}
                             MPA: /billingAccounts/{billingAccountName}/customers/{customerName}
    -Workload              'Production' or 'DevTest'. Defaults to 'Production'.
    -ManagementGroupId     (Optional) Management Group resource ID to assign the new subscription.
    -SubscriptionOwnerId   (Optional) ObjectId of user/SP to set as subscription owner.
    -BudgetAlertEmails     Email addresses to receive the 80% budget alert. (Mandatory)

.EXAMPLE
    .\New-TDM-Subscription.ps1 `
      -Username alice -Id 42 `
      -BillingScope "/billingAccounts/1234567/billingProfiles/contoso/invoiceSections/prod" `
      -Workload Production `
      -ManagementGroupId "/providers/Microsoft.Management/managementGroups/Contoso" `
      -BudgetAlertEmails @("alice@contoso.com","finops@contoso.com")
#>

param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Username,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Id,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$BillingScope,

    [Parameter()]
    [ValidateSet('Production','DevTest')]
    [string]$Workload = 'Production',

    [Parameter()]
    [string]$ManagementGroupId,

    [Parameter()]
    [string]$SubscriptionOwnerId,

    [Parameter(Mandatory)]
    [string[]]$BudgetAlertEmails
)

# Compose display name and alias for the subscription alias request
$year = (get-date).Year
$displayName = "TDM-$year-S2-$Username-$Id"
$aliasName   = ($displayName.ToLower() -replace '[^a-z0-9-]', '-')

Write-Host "==> Creating subscription '$displayName' (alias '$aliasName')"

# Basic validation for BillingScope (cmdlet expects non-/providers form)
if ($BillingScope -like '/providers/*') {
    Write-Warning "BillingScope should NOT start with '/providers/...'. Use the concise form documented for your agreement type."
}

# Ensure required Az modules are available
$requiredModules = @('Az.Accounts','Az.Subscription','Az.Billing')
foreach ($m in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $m)) {
        Write-Error "$m module is required. Install with: Install-Module $m -Scope CurrentUser"
        exit 1
    }
}

# Authenticate if needed
try {
    if (-not (Get-AzContext)) { Connect-AzAccount -Scope Process | Out-Null }
}
catch {
    Write-Error "Failed to authenticate: $_"
    exit 1
}

# Build parameters for New-AzSubscriptionAlias
$aliasParams = @{
    AliasName        = $aliasName
    SubscriptionName = $displayName     # alias for -DisplayName
    BillingScope     = $BillingScope
    Workload         = $Workload
}

if ($ManagementGroupId)   { $aliasParams['ManagementGroupId']   = $ManagementGroupId }
if ($SubscriptionOwnerId) { $aliasParams['SubscriptionOwnerId'] = $SubscriptionOwnerId }

# Create the subscription (Subscription Alias API)
try {
    $aliasResult = New-AzSubscriptionAlias @aliasParams -ErrorAction Stop
    Write-Host "ProvisioningState: $($aliasResult.ProvisioningState)"
    Write-Host "SubscriptionId   : $($aliasResult.SubscriptionId)"
}
catch {
    Write-Error "Subscription creation failed: $($_.Exception.Message)"
    Write-Host "Common causes:"
    Write-Host " - Incorrect BillingScope format (must be the concise form per MCA/EA/MPA)."
    Write-Host " - Insufficient billing permissions (invoice section/profile/account)."
    exit 1
}

# If no SubscriptionId yet, try to fetch it from the alias name
if (-not $aliasResult.SubscriptionId) {
    try {
        $aliasLookup = Get-AzSubscriptionAlias -AliasName $aliasName -ErrorAction Stop
        $newSubId = $aliasLookup.SubscriptionId
    }
    catch {
        Write-Error "Unable to retrieve SubscriptionId for alias '$aliasName': $_"
        exit 1
    }
}
else {
    $newSubId = $aliasResult.SubscriptionId
}

# Select the new subscription context
try {
    Select-AzSubscription -SubscriptionId $newSubId -ErrorAction Stop | Out-Null
}
catch {
    Write-Error "Failed to select the new subscription context ($newSubId): $_"
    exit 1
}

# === Add a $100 monthly budget with an 80% alert ===
$budgetName    = "Budget-$displayName"
$budgetAmount  = 100          # uses subscription's billing currency
$thresholdPct  = 80
$timeGrain     = "Monthly"
$notifKey      = "Warn80Percent"

# Budgets should start on the first day of the current month (UTC)
$monthStartLocal = Get-Date -Year (Get-Date).Year -Month (Get-Date).Month -Day 1
$startDate       = [DateTime]$monthStartLocal.ToUniversalTime()
$endDate         = (Get-Date).AddYears(2)  # optional; extend as needed

Write-Host "==> Creating budget '$budgetName' = $$budgetAmount Monthly, starting $($startDate.ToString('yyyy-MM-dd')), with $thresholdPct% alert"

try {
    $budget = New-AzConsumptionBudget `
        -Amount $budgetAmount `
        -Name $budgetName `
        -Category Cost `
        -StartDate $startDate `
        -EndDate $endDate `
        -TimeGrain $timeGrain `
        -NotificationKey $notifKey `
        -NotificationThreshold $thresholdPct `
        -NotificationEnabled `
        -ContactEmail $BudgetAlertEmails `
        -ErrorAction Stop

    Write-Host "Budget created. Id: $($budget.Id)"
    $thresholdValue = [math]::Round($budgetAmount * $thresholdPct / 100, 2)
    Write-Host "Alert '$notifKey' enabled at $thresholdPct% (≈ $$thresholdValue)."
}
catch {
    Write-Error "Budget creation failed: $($_.Exception.Message)"
    Write-Host "Troubleshooting tips:"
    Write-Host " - Verify Az.Billing is installed and up to date."
    Write-Host " - Ensure Cost Management permissions at subscription scope."
    Write-Host " - Budget start date must be the 1st of a month."
    exit 1
}

Write-Host "==> Done. Subscription '$displayName' created and budget/alert configured."
