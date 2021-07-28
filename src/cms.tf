resource "azurerm_resource_group" "rg_cms" {
  name     = format("%s-cms-rg", local.project)
  location = var.location

  tags = var.tags
}

resource "azurerm_container_registry" "container_registry" {
  name                = join("", [replace(var.prefix, "-", ""), var.env_short, "arc"])
  resource_group_name = azurerm_resource_group.rg_cms.name
  location            = azurerm_resource_group.rg_cms.location
  sku                 = var.sku_container_registry
  admin_enabled       = true


  dynamic "retention_policy" {
    for_each = var.sku_container_registry == "Premium" ? [var.retention_policy_acr] : []
    content {
      days    = retention_policy.value["days"]
      enabled = retention_policy.value["enabled"]
    }
  }

  tags = var.tags
}

# TODO use azurerm module
module "cms" {
  # depends_on = [azurerm_key_vault_access_policy.terraform_policy]
  #, azurerm_key_vault_access_policy.adgroup_admin_policy, azurerm_key_vault_access_policy.adgroup_contributors_policy]
  # source = "git::https://github.com/pagopa/azurerm.git//app_service?ref=v1.0.38"
  source = "./modules/app_service"

  name                = format("%s-cms", local.project)
  plan_name           = format("%s-plan-cms", local.project)
  resource_group_name = azurerm_resource_group.rg_cms.name
  plan_kind           = "Linux"

  plan_sku_tier     = var.backend_sku.tier
  plan_sku_size     = var.backend_sku.size
  plan_sku_capacity = var.backend_sku.capacity
  plan_reserved     = true

  health_check_path = "/"

  storage_account = {
    name         = module.storage_account.name
    account_name = module.storage_account.name
    share_name   = "assets"
    access_key   = module.storage_account.primary_access_key
    mount_path   = "/var/www/html/web/app/uploads"
  }

  app_settings = {

    DB_NAME     = var.database_name
    DB_USER     = format("%s@%s", data.azurerm_key_vault_secret.db_administrator_login.value, azurerm_mysql_server.mysql_server.fqdn)
    DB_PASSWORD = data.azurerm_key_vault_secret.db_administrator_login_password.value
    DB_HOST     = azurerm_mysql_server.mysql_server.fqdn
    WP_ENV      = var.cms_env
    WP_HOME     = var.cms_base_url
    WP_SITEURL  = format("%s/wp", var.cms_base_url)

    MICROSOFT_AZURE_ACCOUNT_KEY            = module.storage_account.primary_access_key
    MICROSOFT_AZURE_ACCOUNT_NAME           = module.storage_account.name
    MICROSOFT_AZURE_CONTAINER              = "media"
    MICROSOFT_AZURE_USE_FOR_DEFAULT_UPLOAD = true

    # https://github.com/terraform-providers/terraform-provider-azurerm/issues/5073#issuecomment-564296263
    # in terraform app service needs log block instead WEBSITE_HTTPLOGGING_RETENTION_DAYS
    # WEBSITE_HTTPLOGGING_RETENTION_DAYS  = 7
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = false

    DOCKER_REGISTRY_SERVER_URL      = "https://${azurerm_container_registry.container_registry.login_server}"
    DOCKER_REGISTRY_SERVER_USERNAME = azurerm_container_registry.container_registry.admin_username
    DOCKER_REGISTRY_SERVER_PASSWORD = azurerm_container_registry.container_registry.admin_password

    # DNS configuration to use private endpoint
    WEBSITE_DNS_SERVER     = "168.63.129.16"
    WEBSITE_VNET_ROUTE_ALL = 1

    # # application insights
    # APPLICATIONINSIGHTS_CONNECTION_STRING = format("InstrumentationKey=%s",
    # azurerm_application_insights.application_insights.instrumentation_key)
  }

  linux_fx_version = "DOCKER|mcr.microsoft.com/appsvc/staticsite:latest"

  always_on = "true"

  subnet_name = module.subnet_cms_outbound.name
  subnet_id   = module.subnet_cms_outbound.id

  tags = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "cms_private_link" {
  name                  = format("%s-private-dns-zone-link", module.cms.name)
  resource_group_name   = azurerm_resource_group.rg_vnet.name
  private_dns_zone_name = azurerm_private_dns_zone.privatelink_azurewebsites_net.name
  virtual_network_id    = azurerm_virtual_network.vnet.id

  tags = var.tags
}

resource "azurerm_private_endpoint" "cms" {
  name                = format("%s-private-endpoint", module.cms.name)
  location            = var.location
  resource_group_name = azurerm_resource_group.rg_cms.name
  subnet_id           = module.subnet_cms_inbound.id

  private_dns_zone_group {
    name                 = format("%s-private-dns-zone-group", module.cms.name)
    private_dns_zone_ids = [azurerm_private_dns_zone.privatelink_azurewebsites_net.id, azurerm_private_dns_zone.private[0].id]
  }

  private_service_connection {
    name                           = format("%s-private-service-connection", module.cms.name)
    private_connection_resource_id = module.cms.id
    is_manual_connection           = false
    subresource_names              = ["sites"]
  }
}
