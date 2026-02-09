terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.5.0"
    }
  }
}
provider "azurerm" {
  features {}
}

locals {
  core_services_vnet_subnets = cidrsubnets("10.0.0.0/22", 6, 2, 4, 3)
  # name                 = var.name
  subnet_address_space = [local.core_services_vnet_subnets[3]]
}

## Section to provide a random Azure region for the resource group
# This allows us to randomize the region for the resource group.
module "regions" {
  source  = "Azure/regions/azurerm"
  version = "~> 0.3"
}

# This allows us to randomize the region for the resource group.
resource "random_integer" "region_index" {
  max = length(module.regions.regions) - 1
  min = 0
}
## End of section to provide a random Azure region for the resource group

# This ensures we have unique CAF compliant names for our resources.
module "naming" {
  source  = "Azure/naming/azurerm"
  version = "~> 0.3"
}

# This is required for resource modules
resource "azurerm_resource_group" "this" {
  location = var.location
  name     = module.naming.resource_group.name_unique
}

# VNET for private endpoints
resource "azurerm_virtual_network" "this" {
  location            = azurerm_resource_group.this.location
  name                = module.naming.virtual_network.name_unique
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.0.0.0/22"]
  tags                = var.tags
}

# Subnet for private endpoints
resource "azurerm_subnet" "private_endpoints" {
  address_prefixes                  = local.subnet_address_space
  name                              = "private-endpoints-subnet"
  resource_group_name               = azurerm_resource_group.this.name
  virtual_network_name              = azurerm_virtual_network.this.name
  private_endpoint_network_policies = "Enabled"
}

# Create Private DNS Zone for Search Service
resource "azurerm_private_dns_zone" "search" {
  name                = "privatelink.search.windows.net"
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

# Create Private DNS Zone Virtual Network Link for Search
resource "azurerm_private_dns_zone_virtual_network_link" "search" {
  name                  = "${azurerm_virtual_network.this.name}-search-link"
  private_dns_zone_name = azurerm_private_dns_zone.search.name
  resource_group_name   = azurerm_resource_group.this.name
  virtual_network_id    = azurerm_virtual_network.this.id
  tags                  = var.tags
}

# Create Private DNS Zone for Storage Blob
resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

# Create Private DNS Zone Virtual Network Link for Blob
resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  name                  = "${azurerm_virtual_network.this.name}-blob-link"
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  resource_group_name   = azurerm_resource_group.this.name
  virtual_network_id    = azurerm_virtual_network.this.id
  tags                  = var.tags
}

# Storage Account for Shared Private Link Service
resource "azurerm_storage_account" "storage" {
  account_replication_type = "LRS"
  account_tier             = "Standard"
  location                 = azurerm_resource_group.this.location
  name                     = "${module.naming.storage_account.name_unique}01"
  resource_group_name      = azurerm_resource_group.this.name
  tags                     = var.tags

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }
}

# Private Endpoint for Storage Account
resource "azurerm_private_endpoint" "storage_blob" {
  location            = azurerm_resource_group.this.location
  name                = "pe-${azurerm_storage_account.storage.name}-blob"
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = var.tags

  private_service_connection {
    is_manual_connection           = false
    name                           = "psc-${azurerm_storage_account.storage.name}-blob"
    private_connection_resource_id = azurerm_storage_account.storage.id
    subresource_names              = ["blob"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
  }
}

# This is the module call for the Search Service
module "search_service" {
  source = "../../"

  # source             = "Azure/avm-res-search-searchservice/azurerm"
  # ...
  location                     = azurerm_resource_group.this.location
  name                         = module.naming.search_service.name_unique
  resource_group_name          = azurerm_resource_group.this.name
  allowed_ips                  = var.azure_ai_allowed_ips
  enable_telemetry             = var.enable_telemetry # see variables.tf
  local_authentication_enabled = var.local_authentication_enabled
  managed_identities = {
    system_assigned = true
  }
  private_endpoints = {
    primary = {
      private_dns_zone_resource_ids = [azurerm_private_dns_zone.search.id]
      private_dns_zone_name         = azurerm_private_dns_zone.search.name
      subnet_resource_id            = azurerm_subnet.private_endpoints.id
    }
  }
  public_network_access_enabled = false
  sku                           = "standard"

  # Shared Private Link Services to Storage Accounts
  shared_private_link_services = {
    spls_blob = {
      name               = "spls-${azurerm_storage_account.storage.name}-blob"
      subresource_name   = "blob"
      target_resource_id = azurerm_storage_account.storage.id
      request_message    = "Please approve shared private link for blob access"
    }
  }
}
