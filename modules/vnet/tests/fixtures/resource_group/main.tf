terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 3.0" }
    random  = { source = "hashicorp/random", version = "~> 3.5" }
  }
}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_resource_group" "test" {
  name     = "rg-vnet-module-test-${random_string.suffix.result}"
  location = "eastus"
  tags = {
    purpose    = "terraform-module-testing"
    managed_by = "terraform-test"
  }
}

output "name" {
  value = azurerm_resource_group.test.name
}
