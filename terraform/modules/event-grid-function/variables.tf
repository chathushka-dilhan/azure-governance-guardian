variable "project_name" {
  description = "A unique prefix for resources."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group where Function App and related resources will be deployed."
  type        = string
}

variable "location" {
  description = "The Azure region for Function App deployment."
  type        = string
}

variable "storage_account_name" {
  description = "Base name for the Azure Function App's storage account."
  type        = string
}

variable "app_service_plan_name" {
  description = "Name for the Azure Function App's App Service Plan."
  type        = string
}

variable "function_app_name" {
  description = "Name for the Azure Function App (Policy Processor)."
  type        = string
}

variable "vnet_integration_subnet_id" {
  description = "ID of the subnet for Function App VNet integration. Leave empty for no VNet integration."
  type        = string
  default     = ""
}

variable "automation_account_id" {
  description = "ID of the Azure Automation Account for runbook invocation."
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "ID of the Log Analytics Workspace for logging."
  type        = string
}

variable "subscription_id" {
  description = "The Azure Subscription ID where the Event Grid subscription will be created."
  type        = string
}

variable "logic_app_http_trigger_url" {
  description = "HTTP POST endpoint URL for the Logic App for notifications."
  type        = string
}

variable "automation_account_resource_group_name" {
  description = "The resource group name of the Automation Account."
  type        = string
}

variable "automation_account_name" {
  description = "The name of the Automation Account."
  type        = string
}