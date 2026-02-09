resource "azurerm_search_shared_private_link_service" "this" {
  for_each = var.shared_private_link_services

  name               = each.value.name
  search_service_id  = azurerm_search_service.this.id
  subresource_name   = each.value.subresource_name
  target_resource_id = each.value.target_resource_id
  request_message    = each.value.request_message

  dynamic "timeouts" {
    for_each = each.value.timeouts == null ? [] : [each.value.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }
}
