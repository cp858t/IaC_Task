###############################################################################
# Module: vnet – Native Terraform Tests
# Run: cd modules/vnet && terraform test
#
# Requirements: Azure credentials with Contributor on a test subscription.
# These tests CREATE and DESTROY real resources; they complete in ~2 minutes.
###############################################################################

# ── Provider configuration ──────────────────────────────────────────────────
provider "azurerm" {
  features {}
}

# ── Shared setup: resource group used by all test runs ─────────────────────
run "setup_resource_group" {
  command = apply

  module {
    source = "./tests/fixtures/resource_group"
  }
}

# ── Test 1: Basic VNET with no NSG ─────────────────────────────────────────
run "basic_vnet_no_nsg" {
  command = apply

  variables {
    vnet_name           = "vnet-test-basic-eus"
    location            = "eastus"
    resource_group_name = run.setup_resource_group.name
    environment         = "dev"
    address_space       = ["10.99.0.0/16"]
    subnets = [
      {
        name             = "snet-default"
        address_prefixes = ["10.99.0.0/24"]
        create_nsg       = false
      }
    ]
  }

  assert {
    condition     = output.vnet_id != ""
    error_message = "vnet_id output must not be empty."
  }

  assert {
    condition     = length(output.subnet_ids) == 1
    error_message = "Expected exactly one subnet."
  }

  assert {
    condition     = length(output.nsg_ids) == 0
    error_message = "No NSGs should be created when create_nsg=false."
  }
}

# ── Test 2: VNET with NSG + rules ──────────────────────────────────────────
run "vnet_with_nsg_and_rules" {
  command = apply

  variables {
    vnet_name           = "vnet-test-nsg-eus"
    location            = "eastus"
    resource_group_name = run.setup_resource_group.name
    environment         = "dev"
    address_space       = ["10.98.0.0/16"]
    subnets = [
      {
        name             = "snet-app"
        address_prefixes = ["10.98.1.0/24"]
        create_nsg       = true
        nsg_rules = [
          {
            name                   = "allow-https"
            priority               = 100
            direction              = "Inbound"
            access                 = "Allow"
            protocol               = "Tcp"
            destination_port_range = "443"
          }
        ]
      }
    ]
  }

  assert {
    condition     = length(output.nsg_ids) == 1
    error_message = "Expected one NSG for the app subnet."
  }

  assert {
    condition     = contains(keys(output.nsg_ids), "snet-app")
    error_message = "NSG map must contain key 'snet-app'."
  }
}

# ── Test 3: Multiple subnets ────────────────────────────────────────────────
run "vnet_multiple_subnets" {
  command = apply

  variables {
    vnet_name           = "vnet-test-multi-eus"
    location            = "eastus"
    resource_group_name = run.setup_resource_group.name
    environment         = "dev"
    address_space       = ["10.97.0.0/16"]
    subnets = [
      { name = "snet-a", address_prefixes = ["10.97.1.0/24"], create_nsg = false },
      { name = "snet-b", address_prefixes = ["10.97.2.0/24"], create_nsg = false },
      { name = "snet-c", address_prefixes = ["10.97.3.0/24"], create_nsg = true  }
    ]
  }

  assert {
    condition     = length(output.subnet_ids) == 3
    error_message = "Expected exactly 3 subnets."
  }

  assert {
    condition     = length(output.nsg_ids) == 1
    error_message = "Only snet-c should have an NSG."
  }
}

# ── Test 4: Input validation – invalid environment ──────────────────────────
run "validation_invalid_environment" {
  command = plan
  expect_failures = [var.environment]

  variables {
    vnet_name           = "vnet-test"
    location            = "eastus"
    resource_group_name = "rg-test"
    environment         = "qa" # invalid – must be dev|staging|prod
    address_space       = ["10.0.0.0/16"]
    subnets             = []
  }
}
