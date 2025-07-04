# Create Resource Group for Function App if it doesn't exist
resource "azurerm_resource_group" "func_rg" {
  name     = var.resource_group_name
  location = var.location
  tags = {
    Project = var.project_name
  }
}

# Storage Account for Function App (required by Azure Functions)
resource "azurerm_storage_account" "func_storage" {
  name                     = "${var.storage_account_name}${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.func_rg.name
  location                 = azurerm_resource_group.func_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS" # Or "GRS" for geo-redundancy
  min_tls_version          = "TLS1_2" # Enforce TLS 1.2
  tags = {
    Project = var.project_name
  }
}

# Random suffix for globally unique storage account name
resource "random_string" "suffix" {
  length  = 5
  special = false
  upper   = false
  numeric = true
}

# App Service Plan for Function App
resource "azurerm_app_service_plan" "func_plan" {
  name                = var.app_service_plan_name
  location            = azurerm_resource_group.func_rg.location
  resource_group_name = azurerm_resource_group.func_rg.name
  kind                = "FunctionApp"
  sku {
    tier = "Consumption" # Serverless plan
    size = "Y1"
  }
  tags = {
    Project = var.project_name
  }
}

# Azure Function App (Policy Processor)
resource "azurerm_function_app" "policy_processor_func" {
  name                       = var.function_app_name
  location                   = azurerm_resource_group.func_rg.location
  resource_group_name        = azurerm_resource_group.func_rg.name
  app_service_plan_id        = azurerm_app_service_plan.func_plan.id
  storage_account_name       = azurerm_storage_account.func_storage.name
  storage_account_access_key = azurerm_storage_account.func_storage.primary_access_key
  os_type                    = "Linux" # Or "Windows"
  version                    = "~3"    # Python 3.9 for example
  https_only                 = true    # Enforce HTTPS

  # Enable System-Assigned Managed Identity
  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME" = "python"
    "WEBSITE_RUN_FROM_PACKAGE" = "1" # Best practice for deployment
    "AUTOMATION_ACCOUNT_ID"    = var.automation_account_id # Pass Automation Account ID to function
    "LOG_ANALYTICS_WORKSPACE_ID" = var.log_analytics_workspace_id # Pass Log Analytics Workspace ID
    "SUBSCRIPTION_ID"          = var.subscription_id # Pass subscription ID for resource graph queries
    "LOGIC_APP_HTTP_TRIGGER_URL" = var.logic_app_http_trigger_url # Pass Logic App URL for notifications
    "AUTOMATION_ACCOUNT_RESOURCE_GROUP" = var.automation_account_resource_group_name # New: Pass Automation Account's RG name
    "AUTOMATION_ACCOUNT_NAME" = var.automation_account_name # New: Pass Automation Account's name
    # Add other environment variables needed by your function
  }

  # VNet Integration if subnet ID is provided
  dynamic "vnet_integration" {
    for_each = var.vnet_integration_subnet_id != "" ? [1] : []
    content {
      subnet_id = var.vnet_integration_subnet_id
    }
  }

  # Deploy the function code from the local source directory
  site_config {
    # This block is for deploying code directly from a local path.
    # In a production setup, you'd typically use Azure DevOps, GitHub Actions,
    # or Azure CLI to deploy the function app content.
    # For Terraform to deploy, you would usually zip the content and use 'content_blob_name'
    # or a CI/CD pipeline. For simplicity here, we'll assume a pre-zipped package or CI/CD.
    # If using WEBSITE_RUN_FROM_PACKAGE = "1", you'd typically upload a zip to storage.
    # For now, this Terraform only provisions the Function App infrastructure.
    # The actual code deployment would be a separate step or a CI/CD pipeline.
  }

  tags = {
    Project = var.project_name
  }
}

# Role Assignment for Function App's Managed Identity
# The Function App needs permissions to read resource data, query policies,
# and potentially trigger Automation Runbooks or write to Log Analytics.
resource "azurerm_role_assignment" "func_reader_role" {
  scope                = var.subscription_id # Or a specific Management Group/Resource Group
  role_definition_name = "Reader"
  principal_id         = azurerm_function_app.policy_processor_func.identity[0].principal_id
}

resource "azurerm_role_assignment" "func_resource_policy_contributor" {
  scope                = var.subscription_id # Or a specific Management Group/Resource Group
  role_definition_name = "Resource Policy Contributor" # For querying policy states
  principal_id         = azurerm_function_app.policy_processor_func.identity[0].principal_id
}

# If the function needs to trigger Automation Account runbooks, it needs 'Automation Operator' role
resource "azurerm_role_assignment" "func_automation_operator" {
  scope                = var.automation_account_id
  role_definition_name = "Automation Operator"
  principal_id         = azurerm_function_app.policy_processor_func.identity[0].principal_id
}

# If the function needs to write to Log Analytics directly (e.g., for custom logs)
resource "azurerm_role_assignment" "func_log_analytics_contributor" {
  scope                = var.log_analytics_workspace_id
  role_definition_name = "Log Analytics Contributor"
  principal_id         = azurerm_function_app.policy_processor_func.identity[0].principal_id
}

# Event Grid System Topic Subscription for Policy Evaluations
# This subscribes to events from the Activity Log related to policy evaluations.
# We'll filter for 'Microsoft.Authorization/policyEvaluations/audit/action' events.
resource "azurerm_eventgrid_event_subscription" "policy_evaluation_sub" {
  name  = "${var.project_name}-policy-eval-sub"
  scope = "/subscriptions/${var.subscription_id}" # Or a specific resource group scope

  event_delivery_schema = "CloudEventSchemaV1_0" # Recommended schema

  # Filter for policy evaluation events
  advanced_filter {
    string_contains {
      key    = "subject"
      values = ["/providers/Microsoft.Authorization/policyEvaluations"]
    }
  }

  # Further filtering can be done within the Azure Function based on 'data.json.effect' etc.
  azure_function_endpoint {
    function_id = azurerm_function_app.policy_processor_func.id
    max_events_per_batch = 10
    preferred_batch_size_in_kilobytes = 64
  }

  labels = ["policy-governance"]
}