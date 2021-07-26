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

data "azurerm_key_vault_certificate" "cms_tls_certificate" {
  name         = format("cms-%s-sitecorporate-pagopa-it", var.env_long)
  key_vault_id = module.key_vault.id
}

resource "azurerm_app_service_certificate" "cms_certificate" {
  name                = format("%s-tls-certificate", local.project)
  resource_group_name = azurerm_resource_group.rg_cms.name
  location            = azurerm_resource_group.rg_cms.location
  key_vault_secret_id = data.azurerm_key_vault_certificate.cms_tls_certificate.secret_id
}

resource "azurerm_app_service_certificate_binding" "cms_certificate_binding" {
  hostname_binding_id = azurerm_app_service_custom_hostname_binding.cms_hostname_binding.id
  certificate_id      = azurerm_app_service_certificate.cms_certificate.id
  ssl_state           = "IpBasedEnabled"
}

resource "azurerm_app_service_custom_hostname_binding" "cms_hostname_binding" {
  hostname            = trim(azurerm_dns_cname_record.dns_cname_record_cms.fqdn, ".")
  app_service_name    = module.portal_backend.name
  resource_group_name = azurerm_resource_group.rg_cms.name
}

# TODO use azurerm module
module "portal_backend" {
  # depends_on = [azurerm_key_vault_access_policy.terraform_policy]
  #, azurerm_key_vault_access_policy.adgroup_admin_policy, azurerm_key_vault_access_policy.adgroup_contributors_policy]
  # source = "git::https://github.com/pagopa/azurerm.git//app_service?ref=v1.0.38"
  source = "./modules/app_service"

  name                = format("%s-portal-backend", local.project)
  plan_name           = format("%s-plan-portal-backend", local.project)
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
    DB_USER     = data.azurerm_key_vault_secret.db_administrator_login.value                    #format("%s@%s", data.azurerm_key_vault_secret.db_administrator_login.value, azurerm_mysql_server.mysql_server.name)
    DB_PASSWORD = data.azurerm_key_vault_secret.db_administrator_login_password.value           #var.db_administrator_login_password
    DB_HOST     = azurerm_mysql_server.mysql_server.fqdn#trimsuffix(azurerm_private_dns_a_record.private_dns_a_record_mysql.fqdn, ".") #
    WP_ENV      = var.cms_env
    WP_HOME     = var.public_hostname
    WP_SITEURL  = format("%s/wp", var.public_hostname)

    MICROSOFT_AZURE_ACCOUNT_KEY            = module.storage_account.primary_access_key
    MICROSOFT_AZURE_ACCOUNT_NAME           = module.storage_account.name
    MICROSOFT_AZURE_CONTAINER              = "media"
    MICROSOFT_AZURE_USE_FOR_DEFAULT_UPLOAD = true

    WEBSITE_HTTPLOGGING_RETENTION_DAYS  = 7
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

  linux_fx_version = "DOCKER|nginx"

  always_on = "true"

  allowed_subnets = [module.subnet_wp.id, module.subnet_db.id]
  # TODO Remove and add allowed_ips it to ignore list
  allowed_ips = ["0.0.0.0/0"]

  subnet_name = module.subnet_wp.name
  subnet_id   = module.subnet_wp.id

  tags = var.tags
}
