output "automation_account_id" {
  description = "The ID of the Azure Automation Account."
  value       = azurerm_automation_account.main.id
}

output "automation_account_principal_id" {
  description = "The Principal ID of the Automation Account's System-Assigned Managed Identity."
  value       = azurerm_automation_account.main.identity[0].principal_id
}