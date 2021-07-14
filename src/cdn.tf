/*
resource "azurerm_resource_group" "rg_cdn" {
  name     = format("%s-cdn-rg", local.project)
  location = var.location
  tags = var.tags
}
*/

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