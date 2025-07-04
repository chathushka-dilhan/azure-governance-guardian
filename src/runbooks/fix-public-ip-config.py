# This Python runbook is designed to detach public IP configurations from network interfaces.
# It expects a JSON payload containing the resource ID of the non-compliant network interface.
# The Automation Account's Managed Identity must have 'Network Contributor' or 'Contributor'
# role on the scope where the network interface resides.

import os
import json
import logging
from azure.identity import DefaultAzureCredential
from azure.mgmt.network import NetworkManagementClient
from azure.mgmt.resource import ResourceManagementClient

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger()

def get_subscription_id():
    """Retrieves the subscription ID from environment variables or Azure context."""
    # In Azure Automation, this might be available as an environment variable
    # or can be inferred from the context of the managed identity.
    # For simplicity, we'll assume it's passed or can be derived.
    # In a real scenario, you might pass it from the Azure Function.
    subscription_id = os.environ.get('AZURE_SUBSCRIPTION_ID')
    if not subscription_id:
        # Fallback for local testing or if not explicitly passed
        # This requires Azure CLI or environment variables to be set up
        try:
            credential = DefaultAzureCredential()
            # Attempt to get subscription from credential context
            # This might not work directly in all Automation scenarios
            # A more robust way is to pass it as a runbook parameter
            logger.warning("AZURE_SUBSCRIPTION_ID not found in environment. Attempting to infer from credential.")
            # This is a placeholder. For production, ensure subscription_id is reliably passed.
            return "YOUR_SUBSCRIPTION_ID_HERE" # <<< IMPORTANT: Replace with actual subscription ID or pass as parameter
        except Exception as e:
            logger.error(f"Could not infer subscription ID: {e}")
            raise Exception("Subscription ID is required.")
    return subscription_id

def fix_public_ip_config(resource_id):
    """
    Detaches public IP configurations from a given network interface.
    """
    logger.info(f"Attempting to fix public IP configuration for Network Interface: {resource_id}")

    try:
        subscription_id = get_subscription_id()
        credential = DefaultAzureCredential()
        network_client = NetworkManagementClient(credential, subscription_id)
        resource_client = ResourceManagementClient(credential, subscription_id)

        # Parse resource ID to get resource group and resource name
        parts = resource_id.split('/')
        resource_group_name = parts[4]
        nic_name = parts[-1]

        logger.info(f"Resource Group: {resource_group_name}, NIC Name: {nic_name}")

        # Get the network interface
        nic = network_client.network_interfaces.get(resource_group_name, nic_name)

        if not nic:
            logger.warning(f"Network Interface {resource_id} not found.")
            return

        updated_ip_configurations = []
        public_ips_detached = 0

        for ip_config in nic.ip_configurations:
            if ip_config.public_ip_address:
                logger.info(f"Detaching Public IP '{ip_config.public_ip_address.id}' from IP configuration '{ip_config.name}'.")
                ip_config.public_ip_address = None # Detach the public IP
                public_ips_detached += 1
            updated_ip_configurations.append(ip_config)

        if public_ips_detached > 0:
            logger.info(f"Updating Network Interface {nic_name} with detached Public IPs.")
            # Update the network interface
            # Note: The `begin_create_or_update` method returns a poller object.
            # We need to wait for the operation to complete.
            poller = network_client.network_interfaces.begin_create_or_update(
                resource_group_name,
                nic_name,
                nic
            )
            poller.result() # Wait for the operation to finish
            logger.info(f"Successfully detached {public_ips_detached} Public IP(s) from {resource_id}.")
        else:
            logger.info(f"No Public IPs found to detach for {resource_id}. Resource already compliant or no public IP.")

    except Exception as e:
        logger.error(f"Error fixing public IP configuration for {resource_id}: {e}", exc_info=True)
        raise # Re-raise the exception to indicate failure in Automation Job

# Main entry point for Azure Automation Runbook
if __name__ == "__main__":
    # When run from Azure Automation, WebhookData will be passed as the first argument
    # If testing locally, you can simulate it.
    import sys
    if len(sys.argv) > 1:
        webhook_data_str = sys.argv[1]
        try:
            webhook_data = json.loads(webhook_data_str)
            resource_id = webhook_data.get('resourceId')
            if resource_id:
                fix_public_ip_config(resource_id)
            else:
                logger.error("Missing 'resourceId' in WebhookData payload.")
        except json.JSONDecodeError:
            logger.error(f"Invalid JSON in WebhookData: {webhook_data_str}")
        except Exception as e:
            logger.error(f"Runbook execution failed: {e}")
    else:
        logger.error("No WebhookData provided. This runbook expects a JSON payload via WebhookData parameter.")
        # Example for local testing:
        # fix_public_ip_config("/subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/YOUR_RG/providers/Microsoft.Network/networkInterfaces/YOUR_NIC_NAME")

