###############################################################################
# Environment: dev
# Region:      eastus
#
# Resources deployed:
#   - Resource Group
#   - VNET (via tf module)
#   - Storage Account + Blob container (cheap, useful for dev artifacts/logs)
#   - Linux Virtual Machine (dev VM / build agent)
#   - Public IP + NIC for the VM
#   - Managed Disk (data volume)
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

   backend "azurerm" {
     resource_group_name  = "rg-tfstate"
     storage_account_name = "satfstate<unique>"
     container_name       = "tfstate"
     key                  = "dev/terraform.tfstate"
   }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
    virtual_machine {
      delete_os_disk_on_deletion     = true
      graceful_shutdown              = false
      skip_shutdown_and_force_delete = false
    }
  }
}

locals {
  name_prefix  = "${var.app_name}-${var.environment}-${var.region_short}"
  rg_name      = "rg-${local.name_prefix}"
  vnet_name    = "vnet-${local.name_prefix}"
  vm_name      = "vm-${local.name_prefix}"
  # Storage account names: lowercase, no hyphens, max 24 chars(keeping this nomenclature in picture using string formation)
  sa_name      = lower(replace("sa${var.app_name}${var.environment}${var.region_short}", "-", ""))

  # ── Mandatory tags (applied to every resource) ─────────────────────────────
  common_tags = {
    environment = var.environment
    region      = var.location
    app         = var.app_name
    managed_by  = "terraform"
    cost_center = var.cost_center
    owner       = var.owner
  }
}

# ---------------------------------------------------------------------------
# Resource Group
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "main" {
  name     = local.rg_name
  location = var.location
  tags     = local.common_tags
}

# ---------------------------------------------------------------------------
# VNET  (tf module)
# ---------------------------------------------------------------------------
module "vnet" {
  source = "../../modules/vnet"

  vnet_name           = local.vnet_name
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  environment         = var.environment
  address_space       = var.vnet_address_space

  subnets = [
    {
      name             = "snet-app"
      address_prefixes = [var.subnet_app_cidr]
      create_nsg       = true
      nsg_rules = [
        {
          name                   = "allow-ssh-inbound"
          priority               = 100
          direction              = "Inbound"
          access                 = "Allow"
          protocol               = "Tcp"
          destination_port_range = "22"
          source_address_prefix  = var.allowed_ssh_cidr
        },
        {
          name                   = "allow-https-inbound"
          priority               = 110
          direction              = "Inbound"
          access                 = "Allow"
          protocol               = "Tcp"
          destination_port_range = "443"
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
        # Only allow traffic from the app subnet
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
# Storage Account + Blob container
# ---------------------------------------------------------------------------
resource "azurerm_storage_account" "main" {
  name                            = local.sa_name
  resource_group_name             = azurerm_resource_group.main.name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"  # Dev: LRS is cost-effective
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  tags                            = local.common_tags

  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 7
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
# Virtual Machine – Public IP
# ---------------------------------------------------------------------------
resource "azurerm_public_ip" "vm" {
  name                = "pip-${local.vm_name}"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

# ---------------------------------------------------------------------------
# Virtual Machine – NIC
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
    public_ip_address_id          = azurerm_public_ip.vm.id
  }
}

# ---------------------------------------------------------------------------
# Virtual Machine – SSH key (generated if not supplied)
# ---------------------------------------------------------------------------
resource "random_password" "vm_admin" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# ---------------------------------------------------------------------------
# Virtual Machine – Linux VM
# ---------------------------------------------------------------------------
resource "azurerm_linux_virtual_machine" "main" {
  name                  = local.vm_name
  resource_group_name   = azurerm_resource_group.main.name
  location              = var.location
  size                  = var.vm_size
  admin_username        = var.vm_admin_username
  network_interface_ids = [azurerm_network_interface.vm.id]
  tags                  = local.common_tags

  # Use SSH key auth; password disabled
  admin_ssh_key {
    username   = var.vm_admin_username
    public_key = var.vm_admin_ssh_public_key
  }

  disable_password_authentication = true

  os_disk {
    name                 = "osdisk-${local.vm_name}"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 64
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  # Cloud-init: install common dev tooling
  custom_data = base64encode(templatefile("${path.module}/cloud-init.yaml", {
    app_name = var.app_name
  }))

  identity {
    type = "SystemAssigned"
  }
}

# ---------------------------------------------------------------------------
# Managed Data Disk
# ---------------------------------------------------------------------------
resource "azurerm_managed_disk" "data" {
  name                 = "disk-data-${local.vm_name}"
  resource_group_name  = azurerm_resource_group.main.name
  location             = var.location
  storage_account_type = "Standard_LRS"
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

# ---------------------------------------------------------------------------
# Grant VM identity read access to the Storage Account
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "vm_storage_reader" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_virtual_machine.main.identity[0].principal_id
}
