# Data source for current Azure subscription ID (used if management_group_id is not set)
data "azurerm_subscription" "current" {}

# Create a resource group for policy-related resources if management_group_id is not set
# This resource group will host policy definitions if they are not scoped to a Management Group
resource "azurerm_resource_group" "policy_rg" {
  count    = var.management_group_id == "" ? 1 : 0 # Only create if management_group_id is NOT provided
  name     = "${var.project_name}-policy-rg"
  location = var.location
  tags = {
    Project = var.project_name
  }
}

# --- Custom Policy Definitions ---
# This block dynamically creates an 'azurerm_policy_definition' resource for each entry
# in the 'var.custom_policy_definitions' map.
# The 'for_each' loop iterates over the map, where each key corresponds to a policy name
# (e.g., "enforce-mandatory-tags") and each value is the JSON content of the policy.
resource "azurerm_policy_definition" "custom_definitions" {
  for_each = var.custom_policy_definitions # Iterates over the map of policy JSONs

  name         = "${var.project_name}-${each.key}" # Uses the map key for naming
  policy_type  = "Custom"
  mode         = jsondecode(each.value).mode
  display_name = jsondecode(each.value).displayName
  description  = jsondecode(each.value).description
  # Scope the policy definition to the Management Group if provided, otherwise to the subscription
  management_group_id = var.management_group_id != "" ? var.management_group_id : null

  policy_rule = jsondecode(each.value).policyRule
  metadata    = jsondecode(each.value).metadata
}

# --- Custom Policy Initiatives (Policy Sets) ---
# Similar to policy definitions, this block dynamically creates an 'azurerm_policy_set_definition'
# resource for each entry in the 'var.custom_initiatives' map.
# Each key corresponds to an initiative name (e.g., "core-governance-initiative")
# and each value is the JSON content of the initiative.
resource "azurerm_policy_set_definition" "custom_initiatives" {
  for_each = var.custom_initiatives # Iterates over the map of initiative JSONs

  name         = "${var.project_name}-${each.key}" # Uses the map key for naming
  policy_type  = "Custom"
  display_name = jsondecode(each.value).displayName
  description  = jsondecode(each.value).description
  # Scope the initiative definition to the Management Group if provided, otherwise to the subscription
  management_group_id = var.management_group_id != "" ? var.management_group_id : null

  # This crucial part maps the policy references within the initiative JSON
  # to the actual IDs of the 'azurerm_policy_definition.custom_definitions' resources created above.
  dynamic "policy_definition_reference" {
    for_each = jsondecode(each.value).policyDefinitions
    content {
      policy_definition_id = azurerm_policy_definition.custom_definitions[policy_definition_reference.value.policyDefinitionId].id
      reference_id         = policy_definition_reference.value.policyDefinitionReferenceId
      parameter_values     = jsonencode(try(policy_definition_reference.value.parameters, {}))
    }
  }
  metadata = jsondecode(each.value).metadata
}

# --- Policy Assignment ---
# This resource assigns a specific initiative (the "core-governance-initiative" in this case).
# If you wanted to assign *all* initiatives dynamically, you would apply 'for_each' here as well.
resource "azurerm_policy_assignment" "core_governance_assignment" {
  name                 = "${var.project_name}-core-governance-assignment"
  display_name         = "Assign: ${azurerm_policy_set_definition.custom_initiatives["core-governance-initiative"].display_name}"
  policy_set_definition_id = azurerm_policy_set_definition.custom_initiatives["core-governance-initiative"].id
  scope                = var.management_group_id != "" ? var.management_group_id : data.azurerm_subscription.current.id
  description          = "Assigns the core governance initiative to the target scope."
  enforcement_mode     = "Default" # Or "DoNotEnforce" for audit-only

  # Parameters for policies within the initiative if they have any
  parameters = jsonencode({})

  identity {
    type = "SystemAssigned" # Required for DeployIfNotExists or Modify effects
  }
}

