# This PowerShell runbook is designed to remediate Azure resources that are missing mandatory tags.
# It expects a JSON payload containing resource details, typically passed from an Azure Function.

param(
    [Parameter(Mandatory=$true)]
    [string]$WebhookData # Input from Azure Function/Webhook, expected to be JSON
)

Write-Output "Starting Remediate-Missing-Tags Runbook..."

try {
    # Convert WebhookData (JSON string) to PowerShell object
    $data = ConvertFrom-Json $WebhookData

    $resourceId = $data.resourceId
    $policyName = $data.policyName
    $missingTagKey = $data.missingTagKey # Assuming the Function identifies the missing tag

    Write-Output "Processing resource: $resourceId for missing tag: $missingTagKey"

    # Connect to Azure (Managed Identity will be used if configured for Automation Account)
    # Ensure the Automation Account's Managed Identity has 'Contributor' or 'Tag Contributor' role on the target scope.
    Connect-AzAccount -Identity

    # Get the resource
    $resource = Get-AzResource -ResourceId $resourceId -ErrorAction Stop

    if (-not $resource) {
        Write-Warning "Resource $resourceId not found. Exiting."
        exit
    }

    # Get current tags
    $tags = $resource.Tags

    # If tags are null, initialize as a new hashtable
    if (-not $tags) {
        $tags = @{}
    }

    # Add or update the missing tag. For this example, we'll set a default value.
    # In a real scenario, the value might come from parameters or a lookup.
    $tags[$missingTagKey] = "AutoRemediated" # Example default value

    Write-Output "Attempting to update tags for $resourceId. New tags: $($tags | ConvertTo-Json)"

    # Update the resource with new tags
    Set-AzResource -ResourceId $resourceId -Tag $tags -Force -ErrorAction Stop

    Write-Output "Successfully remediated resource $resourceId: Added/updated tag '$missingTagKey'."

} catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    # You might want to send a failure notification here
    throw $_.Exception # Re-throw to indicate failure in Automation Job
}

Write-Output "Remediate-Missing-Tags Runbook Finished."
# End of Runbook