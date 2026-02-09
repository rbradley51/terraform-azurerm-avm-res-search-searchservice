output "resource" {
  description = "AI Search resource"
  sensitive   = true
  value       = module.search_service
}

output "shared_private_link_services" {
  description = "Shared Private Link Services created for the Search Service"
  value       = module.search_service.shared_private_link_services
}

output "storage_account_id" {
  description = "Storage Account resource ID"
  value       = azurerm_storage_account.storage.id
}
