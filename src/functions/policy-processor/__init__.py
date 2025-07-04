# azure-governance-guardian/src/functions/policy-processor/__init__.py

import json
import logging
import os
import requests
import azure.functions as func
from azure.identity import DefaultAzureCredential
from azure.mgmt.resourcegraph import ResourceGraphClient
from azure.mgmt.automation import AutomationClient
from msrestazure.azure_exceptions import CloudError

# Configure logging for the Azure Function
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Environment variables (set in Terraform)
AUTOMATION_ACCOUNT_ID = os.environ.get('AUTOMATION_ACCOUNT_ID')
LOG_ANALYTICS_WORKSPACE_ID = os.environ.get('LOG_ANALYTICS_WORKSPACE_ID') # Not directly used for sending logs, but for context
SUBSCRIPTION_ID = os.environ.get('SUBSCRIPTION_ID')
LOGIC_APP_HTTP_TRIGGER_URL = os.environ.get('LOGIC_APP_HTTP_TRIGGER_URL')

# Initialize Azure SDK clients with Managed Identity
# These clients will use the Function App's System-Assigned Managed Identity
try:
    credential = DefaultAzureCredential()
    resource_graph_client = ResourceGraphClient(credential, subscription_id=SUBSCRIPTION_ID)
    # AutomationClient requires the base URL for the Automation Account
    # You might need to derive this from AUTOMATION_ACCOUNT_ID or pass it as another env var
    # For now, we'll assume we can create it with the subscription ID.
    automation_client = AutomationClient(credential, SUBSCRIPTION_ID)
    logger.info("Azure SDK clients initialized successfully.")
except Exception as e:
    logger.error(f"Failed to initialize Azure SDK clients: {e}")
    # This might indicate a problem with Managed Identity setup or permissions.
    # The function will still attempt to process events, but won't be able to use SDKs.


def log_compliance_event_to_la(log_data: dict):
    """
    Logs structured compliance event data.
    In a production scenario, you'd send this to a custom Log Analytics table
    using the Azure Monitor Data Collector API for better querying and reporting.
    For simplicity in this example, we'll log it as a structured message
    that can be parsed by Log Analytics.
    """
    try:
        # Log to Application Insights/Log Analytics via standard logging
        # Log Analytics will ingest this if configured for the Function App
        logger.info(f"ComplianceEvent: {json.dumps(log_data)}")
    except Exception as e:
        logger.error(f"Failed to log compliance event: {e}")

def get_resource_details(resource_id: str) -> dict:
    """
    Fetches additional details about a resource using Azure Resource Graph.
    This helps enrich the notification payload.
    """
    try:
        query = f"resources | where id == '{resource_id}'"
        response = resource_graph_client.resources(query=query)
        if response.data:
            return response.data[0]
        return {}
    except CloudError as e:
        logger.error(f"Resource Graph query failed for {resource_id}: {e.message}")
        return {}
    except Exception as e:
        logger.error(f"An unexpected error occurred during Resource Graph query for {resource_id}: {e}")
        return {}

def invoke_automation_runbook(runbook_name: str, parameters: dict):
    """
    Invokes an Azure Automation runbook.
    Requires Automation Account ID and the Function App's Managed Identity
    to have 'Automation Operator' role on the Automation Account.
    """
    try:
        # The AutomationClient needs the resource group name and automation account name
        # You'll need to pass these as environment variables or derive them from AUTOMATION_ACCOUNT_ID
        # For simplicity, let's assume a hardcoded or derived resource group name for the Automation Account
        automation_account_rg = os.environ.get('AUTOMATION_ACCOUNT_RESOURCE_GROUP', 'rg-azgovguardian-common') # IMPORTANT: Adjust this if your AA is in a different RG
        automation_account_name = os.environ.get('AUTOMATION_ACCOUNT_NAME', 'auto-azgovguardian') # IMPORTANT: Adjust this if your AA has a different name

        logger.info(f"Attempting to start runbook '{runbook_name}' in Automation Account '{automation_account_name}' with parameters: {json.dumps(parameters)}")

        # Start the runbook job
        # Note: The 'start_job' method might vary slightly based on SDK version.
        # This is a conceptual call.
        job = automation_client.jobs.create(
            resource_group_name=automation_account_rg,
            automation_account_name=automation_account_name,
            job_name=f"{runbook_name}-{os.urandom(4).hex()}", # Unique job name
            parameters=parameters
        )
        logger.info(f"Automation job '{job.name}' for runbook '{runbook_name}' started. Job ID: {job.id}")
        return True
    except CloudError as e:
        logger.error(f"Failed to invoke Automation runbook '{runbook_name}': {e.message}")
        return False
    except Exception as e:
        logger.error(f"An unexpected error occurred while invoking runbook '{runbook_name}': {e}", exc_info=True)
        return False

def send_logic_app_notification(payload: dict):
    """
    Sends a notification payload to the Logic App HTTP trigger.
    """
    if not LOGIC_APP_HTTP_TRIGGER_URL:
        logger.warning("LOGIC_APP_HTTP_TRIGGER_URL is not configured. Skipping Logic App notification.")
        return False

    try:
        logger.info(f"Sending notification to Logic App: {json.dumps(payload)}")
        response = requests.post(LOGIC_APP_HTTP_TRIGGER_URL, json=payload, timeout=10)
        response.raise_for_status() # Raise an exception for HTTP errors (4xx or 5xx)
        logger.info(f"Successfully sent notification to Logic App. Status: {response.status_code}")
        return True
    except requests.exceptions.RequestException as e:
        logger.error(f"Failed to send notification to Logic App: {e}", exc_info=True)
        return False
    except Exception as e:
        logger.error(f"An unexpected error occurred during Logic App notification: {e}", exc_info=True)
        return False

def main(event: func.EventGridEvent):
    """
    Main entry point for the Azure Function.
    Processes Event Grid events from Azure Policy evaluations.
    """
    logger.info(f"Python Event Grid trigger function processed an event: {event.id}")

    try:
        event_data = event.get_json()

        # Extract core information from the Event Grid event (Activity Log format)
        resource_id = event_data.get('subject', 'N/A')
        policy_assignment_id = event_data.get('data', {}).get('policyAssignmentId', 'N/A')
        policy_definition_id = event_data.get('data', {}).get('policyDefinitionId', 'N/A')
        compliance_state = event_data.get('data', {}).get('complianceState', 'N/A') # e.g., 'Compliant', 'NonCompliant'
        policy_effect = event_data.get('data', {}).get('policyDefinitionEffect', 'N/A') # e.g., 'audit', 'deny', 'deployIfNotExists'
        event_time = event_data.get('eventTime', 'N/A')
        correlation_id = event_data.get('data', {}).get('correlationId', 'N/A')

        logger.info(f"Processing policy event for Resource: {resource_id}, Policy: {policy_definition_id}, State: {compliance_state}")

        # Prepare base log data for Log Analytics
        base_log_data = {
            "TimeGenerated": event_time,
            "ResourceId": resource_id,
            "PolicyAssignmentId": policy_assignment_id,
            "PolicyDefinitionId": policy_definition_id,
            "ComplianceState": compliance_state,
            "PolicyEffect": policy_effect,
            "CorrelationId": correlation_id,
            "Source": "AzureGovernanceGuardian",
            "EventType": "PolicyEvaluation"
        }

        # --- Conditional Logic for Remediation / Notification ---
        if compliance_state == "NonCompliant":
            # Get enriched resource details for notifications/remediation context
            resource_details = get_resource_details(resource_id)
            logger.info(f"Enriched resource details: {json.dumps(resource_details)}")

            # Add enriched details to log data
            enriched_log_data = {**base_log_data, "ResourceDetails": resource_details}
            log_compliance_event_to_la(enriched_log_data)

            # --- Policy-specific actions ---

            # 1. Enforce Mandatory Tags (Audit/Modify effect)
            if "enforce-mandatory-tags" in policy_definition_id:
                logger.info(f"Non-compliant: Missing mandatory tag for {resource_id}. Triggering remediation.")
                # Assuming the policy definition itself has a 'modify' effect that adds tags,
                # or we trigger an Automation runbook.
                # If using Automation runbook for remediation:
                # invoke_automation_runbook(
                #     runbook_name="remediate-missing-tags",
                #     parameters={
                #         "WebhookData": json.dumps({
                #             "resourceId": resource_id,
                #             "policyName": policy_definition_id,
                #             "missingTagKey": "Environment" # Or derive from policy details
                #         })
                #     }
                # )
                # Send a basic notification about remediation attempt
                send_logic_app_notification({
                    "resourceId": resource_id,
                    "policyName": policy_definition_id,
                    "complianceState": compliance_state,
                    "message": "Resource is missing mandatory tags. Remediation initiated.",
                    "vmName": resource_details.get('name'), # Pass basic details if available
                    "resourceGroup": resource_details.get('resourceGroup'),
                    "location": resource_details.get('location')
                })

            # 2. Deny Public IP on Specific Subnets (Deny effect)
            elif "deny-public-ip-on-subnets" in policy_definition_id:
                logger.info(f"Non-compliant: Attempted Public IP on sensitive subnet for {resource_id}. Policy denied deployment.")
                # No remediation needed as it was denied. Just alert.
                send_logic_app_notification({
                    "resourceId": resource_id,
                    "policyName": policy_definition_id,
                    "complianceState": compliance_state,
                    "message": "Attempted to deploy Public IP on a sensitive subnet. Deployment was DENIED by policy. No remediation needed.",
                    "vmName": resource_details.get('name'),
                    "resourceGroup": resource_details.get('resourceGroup'),
                    "location": resource_details.get('location')
                })

            # 3. Enforce Allowed Locations (Deny effect)
            elif "enforce-allowed-locations" in policy_definition_id:
                logger.info(f"Non-compliant: Resource deployed in unauthorized location for {resource_id}. Policy denied deployment.")
                # No remediation needed as it was denied. Just alert.
                send_logic_app_notification({
                    "resourceId": resource_id,
                    "policyName": policy_definition_id,
                    "complianceState": compliance_state,
                    "message": "Resource deployed in an unauthorized location. Deployment was DENIED by policy. No remediation needed.",
                    "vmName": resource_details.get('name'),
                    "resourceGroup": resource_details.get('resourceGroup'),
                    "location": resource_details.get('location')
                })

            # 4. Enforce Storage Account HTTPS Only (Audit/Modify effect)
            elif "enforce-storage-https-only" in policy_definition_id:
                logger.info(f"Non-compliant: Storage Account not enforcing HTTPS-only for {resource_id}. Triggering remediation.")
                # Trigger Automation runbook for remediation
                invoke_automation_runbook(
                    runbook_name="enforce-storage-https-only",
                    parameters={
                        "WebhookData": json.dumps({
                            "resourceId": resource_id,
                            "policyName": policy_definition_id
                        })
                    }
                )
                # Send a notification about remediation attempt
                send_logic_app_notification({
                    "resourceId": resource_id,
                    "policyName": policy_definition_id,
                    "complianceState": compliance_state,
                    "message": "Storage Account not enforcing HTTPS-only. Remediation initiated.",
                    "vmName": resource_details.get('name'), # This might be a storage account name, adapt schema
                    "resourceGroup": resource_details.get('resourceGroup'),
                    "location": resource_details.get('location')
                })

            # 5. Audit VM Size Restrictions (Audit effect)
            elif "audit-vm-size-restrictions" in policy_definition_id:
                logger.info(f"Non-compliant: VM size restriction violation for {resource_id}. Triggering enhanced notification.")
                # Trigger the enhanced notification runbook
                invoke_automation_runbook(
                    runbook_name="get-vm-details-and-notify",
                    parameters={
                        "WebhookData": json.dumps({
                            "resourceId": resource_id,
                            "policyName": policy_definition_id,
                            "complianceState": compliance_state,
                            "message": "VM size is not compliant with organizational standards. Please review."
                        }),
                        "LogicAppWebhookUrl": LOGIC_APP_HTTP_TRIGGER_URL # Pass Logic App URL to runbook
                    }
                )
                # Note: The Logic App notification is handled by the runbook in this case.
                # No direct Logic App call from here to avoid duplicate notifications.

            # Default action for any other non-compliant policy (if not specifically handled above)
            else:
                logger.info(f"Non-compliant: Unhandled policy {policy_definition_id} for {resource_id}. Sending generic notification.")
                send_logic_app_notification({
                    "resourceId": resource_id,
                    "policyName": policy_definition_id,
                    "complianceState": compliance_state,
                    "message": f"Resource is non-compliant with policy {policy_definition_id}. Manual review required.",
                    "vmName": resource_details.get('name'),
                    "resourceGroup": resource_details.get('resourceGroup'),
                    "location": resource_details.get('location')
                })
        else:
            # Log compliant events as well, but no action needed
            log_compliance_event_to_la(base_log_data)
            logger.info(f"Resource {resource_id} is Compliant with policy {policy_definition_id}.")

    except Exception as e:
        logger.error(f"An unhandled error occurred in the Policy Processor Function: {e}", exc_info=True)
        # Consider sending an alert for function failures as well.

