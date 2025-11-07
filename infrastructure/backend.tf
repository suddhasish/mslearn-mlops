# Terraform Remote Backend Configuration
# Uses existing Azure Storage Account for state management

terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-dev"
    storage_account_name = "mlopstfstatesuddha"
    container_name       = "tfstate"
    key                  = "dev.mlops.tfstate"
    subscription_id      = "b2b8a5e6-9a34-494b-ba62-fe9be95bd398"
  }
}
