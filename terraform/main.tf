# --- Modules ---

# 1. Policy Management Module
# This module will deploy Azure Policy Definitions, Initiatives, and Assignments.
# The actual policy JSONs will be referenced from the 'policies/' directory.
module "policy_management" {
  source = "./modules/policy-management"

  project_name      = var.project_name
  location          = var.location
  management_group_id = var.management_group_id # Assign policies at Management Group level for scale

  # Dynamically load custom policy definitions from the 'policies/custom-definitions' directory
  custom_policy_definitions = {
    for f in fileset("${path.module}/../../policies/custom-definitions", "**/*.json") :
    trimsuffix(f, "/policy.json") => file("${path.module}/../../policies/custom-definitions/${f}")
  }

  # Dynamically load custom policy initiatives from the 'policies/initiatives' directory
  custom_initiatives = {
    for f in fileset("${path.module}/../../policies/initiatives", "*.json") :
    trimsuffix(f, ".json") => file("${path.module}/../../policies/initiatives/${f}")
  }
}

# 2. Event Grid & Policy Processor Function Module
# This module sets up the Azure Function App, Event Grid subscription,
# and the Managed Identity for the function.
module "event_grid_function" {
  source = "./modules/event-grid-function"

  project_name          = var.project_name
  resource_group_name   = var.common_resource_group_name
  location              = var.location
  storage_account_name  = var.function_storage_account_name
  app_service_plan_name = var.function_app_service_plan_name
  function_app_name     = var.function_app_name
  vnet_integration_subnet_id = var.function_vnet_integration_subnet_id
  automation_account_id = module.automation_account.automation_account_id # Pass ID for function to interact with Automation
  log_analytics_workspace_id = module.monitoring_alerting.log_analytics_workspace_id # Pass ID for logging
  subscription_id       = data.azurerm_subscription.current.id
}

# 3. Automation Account Module
# This module deploys the Azure Automation Account and its Managed Identity.
# Runbooks will be uploaded later when we develop the remediation scripts.
module "automation_account" {
  source = "./modules/automation-account"

  project_name        = var.project_name
  resource_group_name = var.common_resource_group_name
  location            = var.location
  automation_account_name = var.automation_account_name

  runbook_paths = {
    "remediate-missing-tags"     = "${path.module}/../../src/runbooks/remediate-missing-tags.ps1"
    "fix-public-ip-config"       = "${path.module}/../../src/runbooks/fix-public-ip-config.py"
    "enforce-storage-https-only" = "${path.module}/../../src/runbooks/enforce-storage-https-only.ps1"
    "get-vm-details-and-notify"  = "${path.module}/../../src/runbooks/get-vm-details-and-notify.ps1"
  }
}

# 4. Monitoring & Alerting Module
# This module sets up the Log Analytics Workspace and Logic Apps for notifications.
module "monitoring_alerting" {
  source = "./modules/monitoring-alerting"

  project_name        = var.project_name
  resource_group_name = var.common_resource_group_name
  location            = var.location
  log_analytics_workspace_name = var.log_analytics_workspace_name
  log_analytics_retention_days = var.log_analytics_retention_days
  logic_app_name      = var.logic_app_name

  # You'd typically pass connection details for Logic Apps here (e.g., Teams webhook URL, email addresses)
  teams_webhook_url = var.teams_webhook_url
  notification_email = var.notification_email
}