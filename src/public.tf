resource "azurerm_resource_group" "rg_public" {
  name     = format("%s-public-rg", local.project)
  location = var.location

  tags = var.tags
}

resource "azurerm_cdn_profile" "cdn_profile_common" {
  name                = format("%s-cdn-common", local.project)
  resource_group_name = azurerm_resource_group.rg_public.name
  location            = azurerm_resource_group.rg_public.location
  sku                 = "Standard_Microsoft"

  tags = var.tags
}

module "cdn_portal_frontend" {
  source = "./modules/cdn_endpoint"

  name                = format("%s-cdnendpoint-frontend", local.project)
  origin_host_name    = module.storage_account_website.primary_web_host
  profile_name        = azurerm_cdn_profile.cdn_profile_common.name
  location            = azurerm_resource_group.rg_public.location
  resource_group_name = azurerm_resource_group.rg_public.name

  # allow HTTP, HSTS will make future connections over HTTPS
  is_http_allowed = true

  global_delivery_rule = {

    cache_expiration_action       = []
    cache_key_query_string_action = []
    modify_request_header_action  = []

    # HSTS
    modify_response_header_action = [{
      action = "Overwrite"
      name   = "Strict-Transport-Security"
      value  = "max-age=31536000"
      },
      # Content-Security-Policy (in Report mode)
      {
        action = "Overwrite"
        name   = "Content-Security-Policy-Report-Only"
        value  = "default-src 'self'; frame-ancestors 'self'; script-src 'self'; style-src 'self'"
    }]

  }

  # rewrite HTTP to HTTPS
  delivery_rule_request_scheme_condition = [{
    name         = "EnforceHTTPS"
    order        = 1
    operator     = "Equal"
    match_values = ["HTTP"]

    url_redirect_action = {
      redirect_type = "Found"
      protocol      = "Https"
      hostname      = null
      path          = null
      fragment      = null
      query_string  = null
    }

  }]

  tags = var.tags
}

resource "null_resource" "cdn_custom_domain" {
  # needs az cli > 2.0.81
  # see https://github.com/Azure/azure-cli/issues/12152
  # remember to do this: https://docs.microsoft.com/it-it/azure/frontdoor/standard-premium/how-to-configure-https-custom-domain#register-azure-front-door

  provisioner "local-exec" {
    command = <<EOT
      az cdn custom-domain create \
        --resource-group ${azurerm_resource_group.rg_public.name} \
        --endpoint-name ${module.cdn_portal_frontend.name} \
        --profile-name ${azurerm_cdn_profile.cdn_profile_common.name} \
        --name ${replace(trim(azurerm_dns_cname_record.frontend.fqdn, "."), ".", "-")} \
        --hostname ${trim(azurerm_dns_cname_record.frontend.fqdn, ".")}
      az cdn custom-domain enable-https \
        --resource-group ${azurerm_resource_group.rg_public.name} \
        --endpoint-name ${module.cdn_portal_frontend.name} \
        --profile-name ${azurerm_cdn_profile.cdn_profile_common.name} \
        --name ${replace(trim(azurerm_dns_cname_record.frontend.fqdn, "."), ".", "-")}
    EOT
  }
}
