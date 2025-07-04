output "policy_assignment_ids" {
  description = "IDs of the deployed Azure Policy Assignments."
  value       = [azurerm_policy_assignment.core_governance_assignment.id]
}

output "policy_definition_ids" {
  description = "IDs of the deployed Azure Policy Definitions."
  # This uses a 'for' expression to extract the 'id' attribute from each policy definition resource
  # created by the 'for_each' loop, resulting in a list of IDs.
  value       = [for k, v in azurerm_policy_definition.custom_definitions : v.id]
}

output "policy_set_definition_ids" {
  description = "IDs of the deployed Azure Policy Set Definitions (Initiatives)."
  # Similarly, this extracts IDs from the dynamically created initiatives.
  value       = [for k, v in azurerm_policy_set_definition.custom_initiatives : v.id]
}