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

resource "azurerm_role_assignment" "app_service_container_registry" {
  scope                            = azurerm_container_registry.container_registry.id
  role_definition_name             = "AcrPull"
  principal_id                     = module.portal_backend.principal_id
  skip_service_principal_aad_check = true
}

data "azurerm_key_vault_secret" "cms_db_password" {
  depends_on = [azurerm_key_vault_access_policy.terraform_cloud_policy]
  #count        = var.agid_spid_public_cert != null ? 1 : 0
  name         = format("%s-cms-db-password", local.project)
  key_vault_id = module.key_vault.id
}

module "portal_backend" {
  source = "git::https://github.com/pagopa/azurerm.git//app_service?ref=v1.0.33"

  name                = format("%s-portal-backend", local.project)
  plan_name           = format("%s-plan-portal-backend", local.project)
  resource_group_name = azurerm_resource_group.rg_cms.name
  plan_kind           = "Linux"

  plan_sku_tier     = var.backend_sku.tier
  plan_sku_size     = var.backend_sku.size
  plan_sku_capacity = var.backend_sku.capacity
  plan_reserved     = true

  health_check_path = "/"

  app_settings = {

    DB_NAME     = var.database_name
    DB_USER     = data.azurerm_key_vault_secret.db_administrator_login.value          #format("%s@%s", data.azurerm_key_vault_secret.db_administrator_login.value, azurerm_mysql_server.mysql_server.name)
    DB_PASSWORD = data.azurerm_key_vault_secret.db_administrator_login_password.value #var.db_administrator_login_password
    DB_HOST     = azurerm_mysql_server.mysql_server.fqdn
    WP_ENV      = var.env_long
    WP_HOME     = var.public_hostname
    WP_SITEURL  = format("%s/wp", var.public_hostname)

    MICROSOFT_AZURE_ACCOUNT_KEY            = module.storage_account.primary_access_key
    MICROSOFT_AZURE_ACCOUNT_NAME           = module.storage_account.name
    MICROSOFT_AZURE_CONTAINER              = "uploads"
    MICROSOFT_AZURE_USE_FOR_DEFAULT_UPLOAD = true

    WEBSITE_HTTPLOGGING_RETENTION_DAYS = 7

    DOCKER_REGISTRY_SERVER_URL      = "https://${azurerm_container_registry.container_registry.login_server}"
    DOCKER_REGISTRY_SERVER_USERNAME = azurerm_container_registry.container_registry.admin_username
    DOCKER_REGISTRY_SERVER_PASSWORD = azurerm_container_registry.container_registry.admin_password

    # # application insights
    # APPLICATIONINSIGHTS_CONNECTION_STRING = format("InstrumentationKey=%s",
    # azurerm_application_insights.application_insights.instrumentation_key)

  }

  #linux_fx_version = format("DOCKER|%s/ccorp-site:%s", azurerm_container_registry.container_registry.login_server, "latest")
  linux_fx_version = "DOCKER|nginx"
  #   linux_fx_version = format("DOCKER|ppareg.azurecr.io/corporate-site-backend:%s", "latest")
  # linux_fx_version = "NODE|14-lts"

  always_on = "true"

  allowed_subnets = [module.subnet_wp.id, module.subnet_db.id, module.subnet_public.id]
  allowed_ips     = ["0.0.0.0/0"]

  subnet_name = module.subnet_wp.name
  subnet_id   = module.subnet_wp.id

  tags = var.tags
}