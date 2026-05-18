###############################################################################
# Environment: prod
# Region:      westus2 (different region for resilience demonstration)
#
# Key differences from dev:
#   - Larger VM SKU
#   - Zone-redundant storage (ZRS)
#   - DDoS protection enabled on VNET
#   - Stricter NSG rules (no public SSH — use Bastion or private VPN)
#   - Longer blob retention (30 days)
###############################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  # backend "azurerm" {
  #   resource_group_name  = "rg-tfstate"
  #   storage_account_name = "satfstate<unique>"
  #   container_name       = "tfstate"
  #   key                  = "prod/terraform.tfstate"
  # }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
    virtual_machine {
      delete_os_disk_on_deletion     = true
      graceful_shutdown              = true
      skip_shutdown_and_force_delete = false
    }
  }
}

locals {
  name_prefix = "${var.app_name}-${var.environment}-${var.region_short}"
  rg_name     = "rg-${local.name_prefix}"
  vnet_name   = "vnet-${local.name_prefix}"
  vm_name     = "vm-${local.name_prefix}"
  sa_name     = lower(replace("sa${var.app_name}${var.environment}${var.region_short}", "-", ""))

  common_tags = {
    environment = var.environment
    region      = var.location
    app         = var.app_name
    managed_by  = "terraform"
    cost_center = var.cost_center
    owner       = var.owner
  }
}

resource "azurerm_resource_group" "main" {
  name     = local.rg_name
  location = var.location
  tags     = local.common_tags
}

module "vnet" {
  source = "../../modules/vnet"

  vnet_name           = local.vnet_name
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  environment         = var.environment
  address_space       = var.vnet_address_space

  # Prod: DDoS protection (comment out if Azure free tier doesn't cover it)
  enable_ddos_protection = var.enable_ddos_protection

  subnets = [
    {
      name             = "snet-app"
      address_prefixes = [var.subnet_app_cidr]
      create_nsg       = true
      nsg_rules = [
        # No direct public SSH in prod — use Azure Bastion or VPN
        {
          name                   = "allow-https-inbound"
          priority               = 100
          direction              = "Inbound"
          access                 = "Allow"
          protocol               = "Tcp"
          destination_port_range = "443"
        },
        {
          name                   = "allow-http-inbound"
          priority               = 110
          direction              = "Inbound"
          access                 = "Allow"
          protocol               = "Tcp"
          destination_port_range = "80"
        },
        {
          name                   = "deny-all-inbound"
          priority               = 4096
          direction              = "Inbound"
          access                 = "Deny"
          protocol               = "*"
          destination_port_range = "*"
        }
      ]
    },
    {
      name             = "snet-data"
      address_prefixes = [var.subnet_data_cidr]
      create_nsg       = true
      nsg_rules = [
        {
          name                       = "allow-app-subnet"
          priority                   = 100
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          destination_port_ranges    = ["1433", "5432", "3306"]
          source_address_prefix      = var.subnet_app_cidr
          destination_address_prefix = "*"
        },
        {
          name                   = "deny-all-inbound"
          priority               = 4096
          direction              = "Inbound"
          access                 = "Deny"
          protocol               = "*"
          destination_port_range = "*"
        }
      ]
    }
  ]

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# Storage Account – ZRS for prod durability
# ---------------------------------------------------------------------------
resource "azurerm_storage_account" "main" {
  name                            = local.sa_name
  resource_group_name             = azurerm_resource_group.main.name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "ZRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  tags                            = local.common_tags

  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 30
    }
  }

  network_rules {
    default_action = "Deny"
    ip_rules       = var.storage_allowed_ips
    bypass         = ["AzureServices"]
  }
}

resource "azurerm_storage_container" "artifacts" {
  name                  = "artifacts"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "logs" {
  name                  = "logs"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

# ---------------------------------------------------------------------------
# VM – Prod uses private IP only (no public IP)
# ---------------------------------------------------------------------------
resource "azurerm_network_interface" "vm" {
  name                = "nic-${local.vm_name}"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  tags                = local.common_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = module.vnet.subnet_ids["snet-app"]
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "main" {
  name                  = local.vm_name
  resource_group_name   = azurerm_resource_group.main.name
  location              = var.location
  size                  = var.vm_size
  admin_username        = var.vm_admin_username
  network_interface_ids = [azurerm_network_interface.vm.id]
  tags                  = local.common_tags

  admin_ssh_key {
    username   = var.vm_admin_username
    public_key = var.vm_admin_ssh_public_key
  }

  disable_password_authentication = true

  os_disk {
    name                 = "osdisk-${local.vm_name}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 128
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_managed_disk" "data" {
  name                 = "disk-data-${local.vm_name}"
  resource_group_name  = azurerm_resource_group.main.name
  location             = var.location
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = var.data_disk_size_gb
  tags                 = local.common_tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "data" {
  managed_disk_id    = azurerm_managed_disk.data.id
  virtual_machine_id = azurerm_linux_virtual_machine.main.id
  lun                = 10
  caching            = "ReadWrite"
}

resource "azurerm_role_assignment" "vm_storage" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_virtual_machine.main.identity[0].principal_id
}
