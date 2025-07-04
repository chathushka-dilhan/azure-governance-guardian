variable "project_name" {
  description = "A unique prefix for resources."
  type        = string
}

variable "location" {
  description = "The Azure region for resource group if needed."
  type        = string
}

variable "management_group_id" {
  description = "The ID of the Management Group where policies will be assigned. Empty for subscription scope."
  type        = string
}

# Map of custom policy definition names to their JSON content.
# The root module reads JSON files and passes them into this map.
variable "custom_policy_definitions" {
  description = "Map of custom policy definition names (e.g., 'enforce-mandatory-tags') to their JSON content."
  type        = map(string)
  default     = {}
}

# Map of custom policy initiative names to their JSON content.
# The root module reads JSON files and passes them into this map.
variable "custom_initiatives" {
  description = "Map of custom policy initiative names (e.g., 'core-governance-initiative') to their JSON content."
  type        = map(string)
  default     = {}
}