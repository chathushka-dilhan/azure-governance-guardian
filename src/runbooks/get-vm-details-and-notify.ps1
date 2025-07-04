# This PowerShell runbook is designed to fetch detailed information about a non-compliant VM
# and send an enriched notification via a Logic App webhook.
# It expects a JSON payload containing the resource ID of the non-compliant VM.
# The Automation Account's Managed Identity must have 'Reader' role on the VM's scope
# and 'Logic App Contributor' (or a custom role allowing POST to Logic Apps) on the Logic App.

param(
    [Parameter(Mandatory=$true)]
    [string]$WebhookData, # Input from Azure Function/Webhook, expected to be JSON
    [Parameter(Mandatory=$true)]
    [string]$LogicAppWebhookUrl # URL of the Logic App HTTP Request trigger
)

Write-Output "Starting Get-VM-Details-and-Notify Runbook..."

try {
    # Convert WebhookData (JSON string) to PowerShell object
    $data = ConvertFrom-Json $WebhookData

    $resourceId = $data.resourceId
    $policyName = $data.policyName
    $complianceState = $data.complianceState
    $message = $data.message

    Write-Output "Processing VM: $resourceId for policy: $policyName"

    # Connect to Azure using Managed Identity
    Connect-AzAccount -Identity

    # Get VM details
    $vm = Get-AzVM -ResourceId $resourceId -Status -ErrorAction SilentlyContinue

    $vmDetails = @{
        ResourceId        = $resourceId
        PolicyName        = $policyName
        ComplianceState   = $complianceState
        Message           = $message
        VMName            = "N/A"
        VMSize            = "N/A"
        ProvisioningState = "N/A"
        PowerState        = "N/A"
        ResourceGroup     = "N/A"
        Location          = "N/A"
        Tags              = @{}
        NetworkInterfaces = @()
        Disks             = @()
    }

    if ($vm) {
        $vmDetails.VMName            = $vm.Name
        $vmDetails.VMSize            = $vm.HardwareProfile.VmSize
        $vmDetails.ProvisioningState = $vm.ProvisioningState
        $vmDetails.PowerState        = $vm.Statuses | Where-Object {$_.Code -like 'PowerState/*'} | Select-Object -ExpandProperty DisplayStatus
        $vmDetails.ResourceGroup     = $vm.ResourceGroupName
        $vmDetails.Location          = $vm.Location
        $vmDetails.Tags              = $vm.Tags

        # Get Network Interface details
        foreach ($nicRef in $vm.NetworkProfile.NetworkInterfaces) {
            $nic = Get-AzNetworkInterface -ResourceId $nicRef.Id -ErrorAction SilentlyContinue
            if ($nic) {
                $nicDetails = @{
                    Name = $nic.Name
                    PrivateIP = ($nic.IpConfigurations | Select-Object -ExpandProperty PrivateIpAddress) -join ", "
                    PublicIP = ($nic.IpConfigurations | Where-Object {$_.PublicIpAddress -ne $null} | Select-Object -ExpandProperty PublicIpAddressId) -join ", "
                }
                $vmDetails.NetworkInterfaces += $nicDetails
            }
        }

        # Get Disk details
        foreach ($diskRef in $vm.StorageProfile.OsDisk, $vm.StorageProfile.DataDisks) {
            if ($diskRef) {
                $diskDetails = @{
                    Name = $diskRef.Name
                    DiskSizeGB = $diskRef.DiskSizeGB
                    StorageAccountType = $diskRef.ManagedDisk.StorageAccountType
                }
                $vmDetails.Disks += $diskDetails
            }
        }
    } else {
        Write-Warning "Could not retrieve detailed information for VM: $resourceId."
    }

    # Prepare payload for Logic App
    $logicAppPayload = @{
        resourceId        = $vmDetails.ResourceId
        policyName        = $vmDetails.PolicyName
        complianceState   = $vmDetails.ComplianceState
        message           = $vmDetails.Message
        vmName            = $vmDetails.VMName
        vmSize            = $vmDetails.VMSize
        provisioningState = $vmDetails.ProvisioningState
        powerState        = $vmDetails.PowerState
        resourceGroup     = $vmDetails.ResourceGroup
        location          = $vmDetails.Location
        tags              = $vmDetails.Tags
        networkInterfaces = $vmDetails.NetworkInterfaces
        disks             = $vmDetails.Disks
    } | ConvertTo-Json -Depth 10 # Use depth to ensure nested objects are fully converted

    Write-Output "Sending enriched notification to Logic App..."

    # Invoke Logic App webhook
    Invoke-RestMethod -Uri $LogicAppWebhookUrl -Method Post -ContentType "application/json" -Body $logicAppPayload -ErrorAction Stop

    Write-Output "Successfully sent enriched notification for VM: $resourceId."

} catch {
    Write-Error "An error occurred in Get-VM-Details-and-Notify Runbook: $($_.Exception.Message)"
    # You might want to send a separate failure notification here if this runbook fails
    throw $_.Exception # Re-throw to indicate failure in Automation Job
}

Write-Output "Get-VM-Details-and-Notify Runbook Finished."
# End of Runbook