variable "project_name" {
  description = "A unique prefix for all resources to ensure naming consistency."
  type        = string
  default     = "azgovguardian"
}

variable "location" {
  description = "The Azure region where resources will be deployed."
  type        = string
  default     = "East US" # Choose your desired Azure region
}

variable "common_resource_group_name" {
  description = "Name of the resource group to deploy common governance resources into."
  type        = string
  default     = "rg-azgovguardian-common"
}

variable "management_group_id" {
  description = "The ID of the Management Group where policies will be assigned. Leave empty to assign to subscription."
  type        = string
  default     = "" # Example: "my-org-mg" or leave empty for subscription scope
}

# --- Azure Function related variables ---
variable "function_storage_account_name" {
  description = "Name for the Azure Function App's storage account. Must be globally unique."
  type        = string
  default     = "stazgovguardianfunc" # Will append random string
}

variable "function_app_service_plan_name" {
  description = "Name for the Azure Function App's App Service Plan."
  type        = string
  default     = "asp-azgovguardian"
}

variable "function_app_name" {
  description = "Name for the Azure Function App (Policy Processor)."
  type        = string
  default     = "func-azgovguardian-processor"
}

variable "function_vnet_integration_subnet_id" {
  description = "ID of the subnet for Function App VNet integration. Must be delegated to 'Microsoft.Web/serverFarms'."
  type        = string
  default     = "" # Example: "/subscriptions/xxx/resourceGroups/yyy/providers/Microsoft.Network/virtualNetworks/zzz/subnets/func-integration-snet"
}

# --- Automation Account related variables ---
variable "automation_account_name" {
  description = "Name for the Azure Automation Account."
  type        = string
  default     = "auto-azgovguardian"
}

# --- Monitoring & Alerting related variables ---
variable "log_analytics_workspace_name" {
  description = "Name for the Log Analytics Workspace."
  type        = string
  default     = "log-azgovguardian"
}

variable "log_analytics_retention_days" {
  description = "Number of days to retain logs in Log Analytics Workspace."
  type        = number
  default     = 90
}

variable "logic_app_name" {
  description = "Name for the Azure Logic App for notifications."
  type        = string
  default     = "logic-azgovguardian-notifier"
}

variable "teams_webhook_url" {
  description = "Webhook URL for Microsoft Teams notifications (if using Teams)."
  type        = string
  default     = ""
  sensitive   = true
}

variable "notification_email" {
  description = "Email address for sending notifications."
  type        = string
  default     = ""
}