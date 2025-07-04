output "policy_assignment_ids" {
  description = "IDs of the deployed Azure Policy Assignments."
  value       = module.policy_management.policy_assignment_ids
}

output "policy_processor_function_url" {
  description = "URL of the Azure Policy Processor Function App."
  value       = module.event_grid_function.function_app_url
}

output "automation_account_id" {
  description = "ID of the Azure Automation Account."
  value       = module.automation_account.automation_account_id
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics Workspace."
  value       = module.monitoring_alerting.log_analytics_workspace_id
}

output "logic_app_http_trigger_url" {
  description = "HTTP POST endpoint URL for the Logic App (if using HTTP trigger)."
  value       = module.monitoring_alerting.logic_app_http_trigger_url
  sensitive   = true
}