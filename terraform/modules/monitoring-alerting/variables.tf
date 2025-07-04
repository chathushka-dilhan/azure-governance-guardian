variable "project_name" {
  description = "A unique prefix for resources."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group where monitoring resources will be deployed."
  type        = string
}

variable "location" {
  description = "The Azure region for monitoring resources deployment."
  type        = string
}

variable "log_analytics_workspace_name" {
  description = "Name for the Log Analytics Workspace."
  type        = string
}

variable "log_analytics_retention_days" {
  description = "Number of days to retain logs in Log Analytics Workspace."
  type        = number
}

variable "logic_app_name" {
  description = "Name for the Azure Logic App for notifications."
  type        = string
}

variable "notification_email" {
  description = "Email address for sending notifications (for Logic App). Required for email action."
  type        = string
  # No default here, as it's mandatory for the email action to be useful.
  # You should provide this value in your root variables.tf or terraform.tfvars.
}

variable "teams_webhook_url" {
  description = "Webhook URL for Microsoft Teams notifications (if using Teams)."
  type        = string
  default     = "" # Provide if using Teams
  sensitive   = true
}