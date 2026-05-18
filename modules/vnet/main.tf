# Module: vnet


terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

locals {
  base_tags = {
    module      = "vnet"
    managed_by  = "terraform"
    environment = var.environment
    region      = var.location
  }
  tags = merge(local.base_tags, var.tags)
}


# Virtual Network

resource "azurerm_virtual_network" "this" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.address_space
  dns_servers         = var.dns_servers
  tags                = local.tags
}


# Subnets

resource "azurerm_subnet" "this" {
  for_each = { for s in var.subnets : s.name => s }

  name                 = each.value.name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = each.value.address_prefixes

  dynamic "delegation" {
    for_each = lookup(each.value, "delegation", null) != null ? [each.value.delegation] : []
    content {
      name = delegation.value.name
      service_delegation {
        name    = delegation.value.service_delegation_name
        actions = lookup(delegation.value, "actions", [])
      }
    }
  }
}


# Network Security Groups (one per subnet that requests one)

resource "azurerm_network_security_group" "this" {
  for_each = {
    for s in var.subnets : s.name => s
    if lookup(s, "create_nsg", false)
  }

  name                = "nsg-${each.value.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = local.tags
}

resource "azurerm_network_security_rule" "this" {
  for_each = {
    for rule in local.nsg_rules_flat : "${rule.subnet_name}-${rule.rule.name}" => rule
  }

  name                        = each.value.rule.name
  priority                    = each.value.rule.priority
  direction                   = each.value.rule.direction
  access                      = each.value.rule.access
  protocol                    = each.value.rule.protocol
  source_port_range           = lookup(each.value.rule, "source_port_range", "*")
  destination_port_range      = lookup(each.value.rule, "destination_port_range", null)
  destination_port_ranges     = lookup(each.value.rule, "destination_port_ranges", null)
  source_address_prefix       = lookup(each.value.rule, "source_address_prefix", "*")
  destination_address_prefix  = lookup(each.value.rule, "destination_address_prefix", "*")
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.this[each.value.subnet_name].name
}

locals {
  # Flatten NSG rules so we can create individual rule resources
  nsg_rules_flat = flatten([
    for s in var.subnets : [
      for rule in lookup(s, "nsg_rules", []) : {
        subnet_name = s.name
        rule        = rule
      }
    ]
    if lookup(s, "create_nsg", false)
  ])
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each = {
    for s in var.subnets : s.name => s
    if lookup(s, "create_nsg", false)
  }

  subnet_id                 = azurerm_subnet.this[each.key].id
  network_security_group_id = azurerm_network_security_group.this[each.key].id
}


# DDoS Protection Plan (optional for security)

resource "azurerm_network_ddos_protection_plan" "this" {
  count               = var.enable_ddos_protection ? 1 : 0
  name                = "ddos-${var.vnet_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = local.tags
}


# Network Watcher (optional – one per region per subscription recommended)
--
resource "azurerm_network_watcher" "this" {
  count               = var.create_network_watcher ? 1 : 0
  name                = "nw-${var.environment}-${var.location}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = local.tags
}
