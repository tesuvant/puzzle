terraform {
  backend "azurerm" {
    resource_group_name  = "vm_rg"
    storage_account_name = "puzzlesa"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}