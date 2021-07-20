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

  name         = format("%s-cms-db-password", local.project)
  key_vault_id = module.key_vault.id
}

resource "azurerm_dns_zone" "cms_dns_zone" {
  name                = var.public_dns_zone
  resource_group_name = azurerm_resource_group.rg_cms.name
}

resource "azurerm_dns_cname_record" "dns_cname_record_cms" {
  depends_on          = [azurerm_dns_zone.cms_dns_zone]
  name                = "cms"
  zone_name           = azurerm_dns_zone.cms_dns_zone.name
  resource_group_name = azurerm_resource_group.rg_cms.name
  ttl                 = 300
  record              = module.portal_backend.default_site_hostname
}

resource "azurerm_dns_txt_record" "dns_txt_record_cms_asuid" {
  depends_on          = [azurerm_dns_zone.cms_dns_zone, module.portal_backend]
  name                = "asuid.${azurerm_dns_cname_record.dns_cname_record_cms.name}"
  zone_name           = azurerm_dns_zone.cms_dns_zone.name
  resource_group_name = azurerm_dns_zone.cms_dns_zone.resource_group_name
  ttl                 = 300
  record {
    value = module.portal_backend.custom_domain_verification_id
  }
}

# resource "azurerm_app_service_custom_hostname_binding" "hostname_binding" {
#   depends_on          = [azurerm_dns_cname_record.dns_cname_record_cms, azurerm_dns_txt_record.dns_txt_record_cms_asuid, module.portal_backend.name]
#   hostname            = trim(azurerm_dns_cname_record.dns_cname_record_cms.fqdn, ".")
#   app_service_name    = module.portal_backend.name
#   resource_group_name = azurerm_resource_group.rg_cms.name
#   # thumbprint          = var.custom_domain.certificate_thumbprint
# }


module "portal_backend" {
  source = "git::https://github.com/pagopa/azurerm.git//app_service?ref=v1.0.38"

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

    DIS_MICROSOFT_AZURE_ACCOUNT_KEY            = module.storage_account.primary_access_key
    DIS_MICROSOFT_AZURE_ACCOUNT_NAME           = module.storage_account.name
    DIS_MICROSOFT_AZURE_CONTAINER              = "media"
    DIS_MICROSOFT_AZURE_USE_FOR_DEFAULT_UPLOAD = true

    WEBSITE_HTTPLOGGING_RETENTION_DAYS = 7

    DOCKER_REGISTRY_SERVER_URL      = "https://${azurerm_container_registry.container_registry.login_server}"
    DOCKER_REGISTRY_SERVER_USERNAME = azurerm_container_registry.container_registry.admin_username
    DOCKER_REGISTRY_SERVER_PASSWORD = azurerm_container_registry.container_registry.admin_password

    # # application insights
    # APPLICATIONINSIGHTS_CONNECTION_STRING = format("InstrumentationKey=%s",
    # azurerm_application_insights.application_insights.instrumentation_key)

  }

  linux_fx_version = "DOCKER|nginx"

  always_on = "true"

  allowed_subnets = [module.subnet_wp.id, module.subnet_db.id]
  # TODO Remove and add allowed_ips it to ignore list
  allowed_ips = ["0.0.0.0/0"]

  subnet_name = module.subnet_wp.name
  subnet_id   = module.subnet_wp.id

  tags = var.tags
}
