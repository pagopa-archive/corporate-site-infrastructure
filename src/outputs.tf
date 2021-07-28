# container registry
output "acr_login_server" {
  value = azurerm_container_registry.container_registry.login_server
}

# web app service
output "cms_hostname" {
  value = module.cms.default_site_hostname
}

output "cms_name" {
  value = module.cms.name
}

# database mysql
output "db_administrator_login" {
  value     = azurerm_mysql_server.mysql_server.administrator_login
  sensitive = true
}

output "db_fqdn" {
  value = azurerm_mysql_server.mysql_server.fqdn
}

output "cdn_hostname" {
  value = module.cdn_portal_frontend.hostname
}

output "cdn_endpoint_name" {
  value = module.cdn_portal_frontend.name
}

output "storage_account_website_name" {
  value = module.storage_account_website.name
}

output "storage_account_name" {
  value = module.storage_account.name
}

output "storage_account_primary_access_key" {
  value     = module.storage_account.primary_access_key
  sensitive = true
}

output "profile_cdn_name" {
  value = azurerm_cdn_profile.cdn_profile_common.name
}

output "resource_group_name_public" {
  value = azurerm_resource_group.rg_public.name
}
