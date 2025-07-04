output "function_app_url" {
  description = "The default hostname of the Azure Function App."
  value       = azurerm_function_app.policy_processor_func.default_hostname
}

output "function_app_id" {
  description = "The ID of the Azure Function App."
  value       = azurerm_function_app.policy_processor_func.id
}

output "function_app_principal_id" {
  description = "The Principal ID of the Function App's System-Assigned Managed Identity."
  value       = azurerm_function_app.policy_processor_func.identity[0].principal_id
}