# This PowerShell runbook enables HTTPS-only traffic for a given Azure Storage Account.
# It expects a JSON payload containing the resource ID of the non-compliant storage account.
# The Automation Account's Managed Identity must have 'Storage Account Contributor' or 'Contributor'
# role on the scope where the storage account resides.

param(
    [Parameter(Mandatory=$true)]
    [string]$WebhookData # Input from Azure Function/Webhook, expected to be JSON
)

Write-Output "Starting Enforce-Storage-HTTPS-Only Runbook..."

try {
    # Convert WebhookData (JSON string) to PowerShell object
    $data = ConvertFrom-Json $WebhookData

    $resourceId = $data.resourceId
    $policyName = $data.policyName # For logging context

    Write-Output "Processing storage account: $resourceId for HTTPS-only enforcement."

    # Connect to Azure using Managed Identity
    Connect-AzAccount -Identity

    # Get the storage account
    $storageAccount = Get-AzStorageAccount -ResourceId $resourceId -ErrorAction Stop

    if (-not $storageAccount) {
        Write-Warning "Storage Account $resourceId not found. Exiting."
        exit
    }

    # Check if HTTPS-only is already enabled
    if ($storageAccount.EnableHttpsTrafficOnly) {
        Write-Output "Storage Account $resourceId already has HTTPS-only traffic enabled. No action needed."
        exit
    }

    Write-Output "Enabling HTTPS-only traffic for Storage Account: $resourceId"

    # Set the property to true
    Set-AzStorageAccount -ResourceId $resourceId -EnableHttpsTrafficOnly $true -ErrorAction Stop

    Write-Output "Successfully enabled HTTPS-only traffic for Storage Account $resourceId."

} catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    # You might want to send a failure notification here
    throw $_.Exception # Re-throw to indicate failure in Automation Job
}

Write-Output "Enforce-Storage-HTTPS-Only Runbook Finished."
# End of Runbook