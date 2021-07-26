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

  account_kind              = "StorageV2"
  account_tier              = "Standard"
  account_replication_type  = "GRS"
  access_tier               = "Hot"
  allow_blob_public_access  = true
  enable_https_traffic_only = true

  resource_group_name = azurerm_resource_group.rg_storage.name
  location            = var.location
  lock                = var.storage_account_lock != null
  lock_scope          = var.storage_account_lock != null ? var.storage_account_lock.scope : null
  lock_level          = var.storage_account_lock != null ? var.storage_account_lock.lock_level : "CanNotDelete"
  lock_notes          = var.storage_account_lock != null ? var.storage_account_lock.notes : null

  tags = var.tags
}

# Containers
resource "azurerm_storage_share" "assets" {
  name                 = "assets"
  storage_account_name = module.storage_account.name
  quota                = 50

  acl {
    id = "MTIzNDU2Nzg5MDEyMzQ1Njc4OTAxMjM0NTY3ODkwMTI"

    access_policy {
      permissions = "rwdl"
      # start       = "2019-07-02T09:38:21.0000000Z"
      # expiry      = "2019-07-02T10:38:21.0000000Z"
    }
  }
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

## Storage account to save logs
module "operations_logs" {
  source = "git::https://github.com/pagopa/azurerm.git//storage_account?ref=v1.0.7"

  name                = replace(format("%s-sa-ops-logs", local.project), "-", "")
  versioning_name     = format("%s-sa-ops-versioning", local.project)
  resource_group_name = azurerm_resource_group.rg_storage.name
  location            = var.location

  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "GRS"
  access_tier              = "Hot"
  enable_versioning        = true

  lock_enabled = true
  lock_name    = "storage-logs"
  lock_level   = "CanNotDelete"
  lock_notes   = null


  tags = var.tags
}
