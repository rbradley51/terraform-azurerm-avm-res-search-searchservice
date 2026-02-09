output "private_endpoints" {
  description = "A map of private endpoints. The map key is the supplied input to var.private_endpoints. The map value is the entire azurerm_private_endpoint resource."
  value       = azurerm_private_endpoint.this
}

# Module owners should include the full resource via a 'resource' output
# https://azure.github.io/Azure-Verified-Modules/specs/terraform/#id-tffr2---category-outputs---additional-terraform-outputs
output "resource" {
  description = "This is the full output for the resource."
  value       = azurerm_search_service.this
}

output "resource_id" {
  description = "The ID of the machine learning workspace."
  value       = azurerm_search_service.this.id
}

output "shared_private_link_services" {
  description = "A map of shared private link services. The map key is the supplied input to var.shared_private_link_services. The map value is the entire azurerm_search_shared_private_link_service resource."
  value       = azurerm_search_shared_private_link_service.this
}
