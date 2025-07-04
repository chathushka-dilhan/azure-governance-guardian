# Configure the Azure Provider
provider "azurerm" {
  features {} # Required for AzureRM provider
}

# Data source for current Azure subscription ID
data "azurerm_subscription" "current" {}

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0.0"
    }
  }
}