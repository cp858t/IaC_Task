output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "vnet_id" {
  value = module.vnet.vnet_id
}

output "vnet_name" {
  value = module.vnet.vnet_name
}

output "subnet_ids" {
  value = module.vnet.subnet_ids
}

output "vm_name" {
  value = azurerm_linux_virtual_machine.main.name
}

output "vm_private_ip" {
  description = "Private IP of the prod VM (no public IP in prod)."
  value       = azurerm_network_interface.vm.private_ip_address
}

output "vm_principal_id" {
  value = azurerm_linux_virtual_machine.main.identity[0].principal_id
}

output "storage_account_name" {
  value = azurerm_storage_account.main.name
}

output "storage_account_primary_endpoint" {
  value     = azurerm_storage_account.main.primary_blob_endpoint
  sensitive = true
}
