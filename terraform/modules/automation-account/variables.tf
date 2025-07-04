variable "project_name" {
  description = "A unique prefix for resources."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group where Automation Account will be deployed."
  type        = string
}

variable "location" {
  description = "The Azure region for Automation Account deployment."
  type        = string
}

variable "automation_account_name" {
  description = "Name for the Azure Automation Account."
  type        = string
}

# Map of runbook names to their file paths for upload.
variable "runbook_paths" {
  description = "Map of runbook names to their file paths for upload."
  type        = map(string)
  default     = {} # Provide an empty map as default if no runbooks are initially needed
}