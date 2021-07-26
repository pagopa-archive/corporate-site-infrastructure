resource "azurerm_resource_group" "rg_db" {
  name     = format("%s-db-rg", local.project)
  location = var.location

  tags = var.tags
}

data "azurerm_key_vault_secret" "db_administrator_login" {
  name         = "db-administrator-login"
  key_vault_id = module.key_vault.id
}

data "azurerm_key_vault_secret" "db_administrator_login_password" {
  name         = "db-admin-login-password"
  key_vault_id = module.key_vault.id
}

resource "azurerm_mysql_server" "mysql_server" {
  name                = format("%s-db-mysql", local.project)
  location            = azurerm_resource_group.rg_db.location
  resource_group_name = azurerm_resource_group.rg_db.name

  administrator_login          = data.azurerm_key_vault_secret.db_administrator_login.value
  administrator_login_password = data.azurerm_key_vault_secret.db_administrator_login_password.value

  sku_name   = var.db_sku_name
  version    = var.db_version
  storage_mb = var.db_storage_mb

  auto_grow_enabled = var.db_auto_grow_enabled

  # public_network_access_enabled    = var.db_public_network_access_enabled
  public_network_access_enabled    = true
  ssl_enforcement_enabled          = var.db_ssl_enforcement_enabled
  ssl_minimal_tls_version_enforced = var.db_ssl_minimal_tls_version_enforced
  backup_retention_days            = 7

  tags = var.tags
}

resource "azurerm_mysql_firewall_rule" "mysql_firewall_rule_public" {
  name                = "azure"
  resource_group_name = azurerm_resource_group.rg_db.name
  server_name         = azurerm_mysql_server.mysql_server.name
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
}

resource "azurerm_mysql_database" "mysql_database" {
  name                = var.database_name
  resource_group_name = azurerm_resource_group.rg_db.name
  server_name         = azurerm_mysql_server.mysql_server.name
  charset             = var.db_charset
  collation           = var.db_collation
}

resource "azurerm_private_dns_zone" "mysql_dns_zone" {
  name                = var.private_dns_zone
  resource_group_name = azurerm_resource_group.rg_db.name

  tags = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "mysql_dns_zone_virtual_link" {

  name                  = format("%s-private-dns-zone-link", local.project)
  resource_group_name   = azurerm_resource_group.rg_db.name
  private_dns_zone_name = azurerm_private_dns_zone.mysql_dns_zone.name
  virtual_network_id    = azurerm_virtual_network.vnet.id

  tags = var.tags
}

resource "azurerm_private_endpoint" "mysql_private_endpoint" {
  name                = format("%s-private-endpoint", local.project)
  location            = var.location
  resource_group_name = azurerm_resource_group.rg_db.name
  subnet_id           = module.subnet_db.id

  private_dns_zone_group {
    name                 = format("%s-private-dns-zone-group", local.project)
    private_dns_zone_ids = [azurerm_private_dns_zone.mysql_dns_zone.id]
  }

  private_service_connection {
    name                           = format("%s-private-service-connection", azurerm_mysql_server.mysql_server.name)
    private_connection_resource_id = azurerm_mysql_server.mysql_server.id
    is_manual_connection           = false
    subresource_names              = ["mysqlServer"]
  }

  tags = var.tags
}

# resource "azurerm_private_endpoint" "mysql_private_endpoint" {
#   name                = format("%s-db-private-endpoint", local.project)
#   location            = azurerm_resource_group.rg_db.location
#   resource_group_name = azurerm_resource_group.rg_db.name
#   subnet_id           = module.subnet_db.id

#   private_dns_zone_group {
#     name                 = format("%s-db-private-dns-zone-group", local.project)
#     private_dns_zone_ids = [azurerm_private_dns_zone.private_dns_zone_mysql.id]
#   }

#   private_service_connection {
#     name                           = format("%s-db-private-service-connection", local.project)
#     private_connection_resource_id = azurerm_mysql_server.mysql_server.id
#     is_manual_connection           = false
#     subresource_names              = ["mysqlSqlServer"]
#   }
# }

resource "azurerm_private_dns_a_record" "private_dns_a_record_mysql" {
  name                = "mysql"
  zone_name           = azurerm_private_dns_zone.mysql_dns_zone.name
  resource_group_name = azurerm_resource_group.rg_db.name
  ttl                 = 300
  records             = azurerm_private_endpoint.mysql_private_endpoint.private_service_connection.*.private_ip_address
}
