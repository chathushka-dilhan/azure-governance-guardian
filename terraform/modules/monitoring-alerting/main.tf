# Create Resource Group for Monitoring & Alerting if it doesn't exist
# This resource group is usually shared with other common governance components.
resource "azurerm_resource_group" "monitor_rg" {
  name     = var.resource_group_name
  location = var.location
  tags = {
    Project = var.project_name
  }
}

# Log Analytics Workspace
# This workspace will collect logs from the Azure Function (Policy Processor)
# and potentially other Azure resources for comprehensive compliance reporting.
resource "azurerm_log_analytics_workspace" "main" {
  name                = var.log_analytics_workspace_name
  location            = azurerm_resource_group.monitor_rg.location
  resource_group_name = azurerm_resource_group.monitor_rg.name
  sku                 = "PerGB2018" # Recommended SKU for production, or "Consumption" for dev/test
  retention_in_days   = var.log_analytics_retention_days

  tags = {
    Project = var.project_name
  }
}

# Azure Logic App for Notifications
# This Logic App will be triggered by the Azure Function (Policy Processor)
# via an HTTP POST request to send notifications (e.g., to Email, Microsoft Teams, ITSM).
resource "azurerm_logic_app_workflow" "notifier_logic_app" {
  name                = var.logic_app_name
  location            = azurerm_resource_group.monitor_rg.location
  resource_group_name = azurerm_resource_group.monitor_rg.name
  workflow_parameters = {}

  workflow_schema = jsonencode({
    "$schema" = "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#",
    "contentVersion" = "1.0.0.0",
    "parameters" = {
      "$connections" = {
        "defaultValue" = {},
        "type" = "Object"
      }
    },
    "triggers" = {
      "manual" = { # This is an HTTP Request trigger
        "type" = "Request",
        "kind" = "Http",
        "inputs" = {
          "schema" = {
            "type" = "object",
            "properties" = {
              "resourceId" = { "type": "string" },
              "policyName" = { "type": "string" },
              "complianceState" = { "type": "string" },
              "message" = { "type": "string" },
              "vmName" = { "type": "string" },
              "vmSize" = { "type": "string" },
              "provisioningState" = { "type": "string" },
              "powerState" = { "type": "string" },
              "resourceGroup" = { "type": "string" },
              "location" = { "type": "string" },
              "tags" = { "type": "object" },
              "networkInterfaces" = { "type": "array" },
              "disks" = { "type": "array" }
            }
          }
        }
      }
    },
    "actions" = {
      "Send_Email_(V2)" = { # Action to send an email using Office 365 Outlook connector
        "runAfter" = {},
        "type" = "ApiConnection",
        "inputs" = {
          "host" = {
            "connection" = {
              "name" = "@parameters('$connections')['office365']['connectionId']" # This connection must be configured in Azure Portal
            }
          },
          "method" = "post",
          "path" = "/v2/Mail",
          "queries" = {
            "mailType" = "Html"
          },
          "body" = {
            "To" = var.notification_email, # Email address from Terraform variable
            "Subject" = "Azure Governance Alert: @{triggerBody()?['policyName']} Non-Compliance",
            "Body" = <<EOT
<h3>Azure Governance Alert: Non-Compliance Detected</h3>
<p><b>Policy:</b> @{triggerBody()?['policyName']}</p>
<p><b>Resource ID:</b> @{triggerBody()?['resourceId']}</p>
<p><b>Compliance State:</b> <span style='color: @{if(equals(triggerBody()?['complianceState'], 'NonCompliant'), 'red', 'green')}'>@{triggerBody()?['complianceState']}</span></p>
<p><b>Message:</b> @{triggerBody()?['message']}</p>
<br>
<h4>Resource Details:</h4> \n
<ul>
    <li><b>Name:</b> @{triggerBody()?['vmName']}</li>
    <li><b>Size:</b> @{triggerBody()?['vmSize']}</li>
    <li><b>Power State:</b> @{triggerBody()?['powerState']}</li>
    <li><b>Resource Group:</b> @{triggerBody()?['resourceGroup']}</li>
    <li><b>Location:</b> @{triggerBody()?['location']}</li>
</ul>
<p><b>Tags:</b> @{json(triggerBody()?['tags'])}</p>
<p><b>Network Interfaces:</b> @{json(triggerBody()?['networkInterfaces'])}</p>
<p><b>Disks:</b> @{json(triggerBody()?['disks'])}</p>
EOT
          }
        }
      },
      # Example: Action to post a message to Microsoft Teams (requires Teams connection)
      "Post_message_in_a_chat_or_channel" = {
        "runAfter": {
          "Send_Email_(V2)": ["Succeeded"] # Run after email is sent
        },
        "type": "ApiConnection",
        "inputs": {
          "host": {
            "connection": {
              "name": "@parameters('$connections')['teams']['connectionId']" # This connection must be configured in Azure Portal
            }
          },
          "method": "post",
          "path": "/v2/teams/channels/@{encodeURIComponent(encodeURIComponent('<your_teams_channel_id>'))}/messages", # Replace with your actual channel ID
          "body": {
            "message": {
               "content": <<EOT
<b>Azure Governance Alert: @{triggerBody()?['policyName']} Non-Compliance</b><br>
Resource: <code>@{triggerBody()?['resourceId']}</code><br>
Compliance State: <span style='color: @{if(equals(triggerBody()?['complianceState'], 'NonCompliant'), 'red', 'green')}'>@{triggerBody()?['complianceState']}</span><br>
Message: @{triggerBody()?['message']}<br>
<br>
<b>VM Details:</b><br>
- Name: @{triggerBody()?['vmName']}<br>
- Size: @{triggerBody()?['vmSize']}<br>
- Power State: @{triggerBody()?['powerState']}<br>
- Location: @{triggerBody()?['location']}<br>
EOT
            }
          }
        }
      }
    }
  })

  tags = { 
    Project = var.project_name
  }
}