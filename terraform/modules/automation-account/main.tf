# Create Resource Group for Automation Account if it doesn't exist
resource "azurerm_resource_group" "auto_rg" {
  name     = var.resource_group_name
  location = var.location
  tags = {
    Project = var.project_name
  }
}

# Azure Automation Account
resource "azurerm_automation_account" "main" {
  name                = var.automation_account_name
  location            = azurerm_resource_group.auto_rg.location
  resource_group_name = azurerm_resource_group.auto_rg.name
  sku_name            = "Basic" # Or "Free" for development, but Basic for production features

  # Enable System-Assigned Managed Identity
  identity {
    type = "SystemAssigned"
  }

  tags = {
    Project = var.project_name
  }
}

# Role Assignment for Automation Account's Managed Identity
# This identity will be used by runbooks to perform remediation actions.
# It needs permissions to modify resources (e.g., add tags, change network config).
# For example, 'Contributor' role on the subscription or specific resource groups.
resource "azurerm_role_assignment" "automation_contributor_role" {
  scope                = data.azurerm_subscription.current.id # Assign Contributor at subscription level (adjust as needed for least privilege)
  role_definition_name = "Contributor"
  principal_id         = azurerm_automation_account.main.identity[0].principal_id
}

# Data source for current Azure subscription ID
data "azurerm_subscription" "current" {}

# --- Runbook Upload ---
# Dynamically upload runbooks from the paths provided in 'var.runbook_paths'.
resource "azurerm_automation_runbook" "runbooks" {
  for_each = var.runbook_paths

  name                    = each.key
  resource_group_name     = azurerm_resource_group.auto_rg.name
  automation_account_name = azurerm_automation_account.main.name
  location                = azurerm_resource_group.auto_rg.location
  runbook_type            = endswith(each.value, ".ps1") ? "PowerShell" : (endswith(each.value, ".py") ? "Python3" : "GraphicalPowerShell")
  content                 = file(each.value)

  description = "Automated remediation runbook for Azure Governance Guardian: ${each.key}"
  tags = {
    Project = var.project_name
  }

  log_progress = true
  log_verbose  = true
}