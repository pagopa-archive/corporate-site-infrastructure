resource "azurerm_resource_group" "rg_storage" {
  name     = format("%s-storage-rg", local.project)
  location = var.location

  tags = var.tags
}

module "storage_account" {
  source = "./modules/storage_account"

  name            = replace(format("%s-sa", local.project), "-", "")
  versioning_name = format("%s-sa-versioning", local.project)
  lock_name       = format("%s-sa-lock", local.project)

  account_kind             = "BlockBlobStorage"
  account_tier             = "Premium"
  account_replication_type = "LRS"
  # account_kind             = "StorageV2"
  # account_tier             = "Standard"
  # account_replication_type = "GRS"
  access_tier               = "Hot"
  allow_blob_public_access  = true
  enable_https_traffic_only = false
  is_hns_enabled            = true
  nfsv3_enabled             = true

  network_rules = {
    default_action             = "Deny"
    bypass                     = ["Metrics", "AzureServices"]
    virtual_network_subnet_ids = [module.subnet_wp.id]
    ip_rules                   = ["93.42.89.226"]
  }

  resource_group_name = azurerm_resource_group.rg_storage.name
  location            = var.location
  lock                = var.storage_account_lock != null
  lock_scope          = var.storage_account_lock != null ? var.storage_account_lock.scope : null
  lock_level          = var.storage_account_lock != null ? var.storage_account_lock.lock_level : "CanNotDelete"
  lock_notes          = var.storage_account_lock != null ? var.storage_account_lock.notes : null

  tags = var.tags
}

resource "azurerm_private_endpoint" "account_private_endpoint" {
  name                = format("%s-account-private-endpoint", local.project)
  location            = azurerm_resource_group.rg_db.location
  resource_group_name = azurerm_resource_group.rg_db.name
  subnet_id           = module.subnet_db.id

  private_dns_zone_group {
    name                 = format("%s-account-private-dns-zone-group", local.project)
    private_dns_zone_ids = [azurerm_private_dns_zone.mysql_dns_zone.id]
  }

  private_service_connection {
    name                           = format("%s-account-private-service-connection", local.project)
    private_connection_resource_id = module.storage_account.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }
}

resource "azurerm_private_dns_a_record" "private_dns_a_record_account" {
  name                = "account"
  zone_name           = azurerm_private_dns_zone.mysql_dns_zone.name
  resource_group_name = azurerm_resource_group.rg_db.name
  ttl                 = 300
  records             = azurerm_private_endpoint.account_private_endpoint.private_service_connection.*.private_ip_address
}

# Containers
resource "azurerm_storage_container" "assets" {
  depends_on            = [module.storage_account]
  name                  = "assets"
  storage_account_name  = module.storage_account.name
  container_access_type = "blob"
}

module "storage_account_website" {
  source = "./modules/storage_account"

  name            = replace(format("%s-sa-ws", local.project), "-", "")
  versioning_name = format("%s-sa-ws-versioning", local.project)
  lock_name       = format("%s-sa-ws-lock", local.project)

  enable_static_website    = true
  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "GRS"
  access_tier              = "Hot"
  allow_blob_public_access = true
  resource_group_name      = azurerm_resource_group.rg_storage.name
  location                 = var.location
  lock                     = var.storage_account_website_lock != null
  lock_scope               = var.storage_account_website_lock != null ? var.storage_account_website_lock.scope : null
  lock_level               = var.storage_account_website_lock != null ? var.storage_account_website_lock.lock_level : "CanNotDelete"
  lock_notes               = var.storage_account_website_lock != null ? var.storage_account_website_lock.notes : null
  tags                     = var.tags
}
