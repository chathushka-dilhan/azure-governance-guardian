output "log_analytics_workspace_id" {
  description = "The ID of the Log Analytics Workspace."
  value       = azurerm_log_analytics_workspace.main.id
}

output "logic_app_http_trigger_url" {
  description = "The HTTP POST endpoint URL for the Logic App (manual trigger)."
  value       = azurerm_logic_app_workflow.notifier_logic_app.access_endpoint
  sensitive   = true # This URL contains a SAS token, treat as sensitive
}