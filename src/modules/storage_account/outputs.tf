output "id" {
  value = azurerm_storage_account.this.id
}

output "primary_connection_string" {
  value     = azurerm_storage_account.this.primary_connection_string
  sensitive = true
}

output "primary_access_key" {
  value     = azurerm_storage_account.this.primary_access_key
  sensitive = true
}

output "primary_blob_endpoint" {
  value = azurerm_storage_account.this.primary_blob_endpoint
}

output "primary_blob_connection_string" {
  value     = azurerm_storage_account.this.primary_blob_connection_string
  sensitive = true
}

output "primary_blob_host" {
  value = azurerm_storage_account.this.primary_blob_host
}

output "primary_web_host" {
  value = azurerm_storage_account.this.primary_web_host
}

output "name" {
  value = var.name
}
