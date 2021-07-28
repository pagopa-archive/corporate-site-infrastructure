resource "azurerm_resource_group" "rg_vnet" {
  name     = format("%s-vnet-rg", local.project)
  location = var.location

  tags = var.tags
}

resource "azurerm_virtual_network" "vnet" {
  name                = format("%s-vnet", local.project)
  location            = azurerm_resource_group.rg_vnet.location
  resource_group_name = azurerm_resource_group.rg_vnet.name
  address_space       = var.cidr_vnet

  tags = var.tags
}

module "subnet_db" {
  source                                         = "git::https://github.com/pagopa/azurerm.git//subnet?ref=v1.0.7"
  name                                           = format("%s-db-subnet", local.project)
  address_prefixes                               = var.cidr_subnet_db
  resource_group_name                            = azurerm_resource_group.rg_vnet.name
  virtual_network_name                           = azurerm_virtual_network.vnet.name
  service_endpoints                              = ["Microsoft.Sql"]
  enforce_private_link_endpoint_network_policies = true
}

module "subnet_cms_outbound" {
  source               = "git::https://github.com/pagopa/azurerm.git//subnet?ref=v1.0.7"
  name                 = format("%s-cms-subnet-outbound", local.project)
  address_prefixes     = var.cidr_subnet_cms_outbound
  resource_group_name  = azurerm_resource_group.rg_vnet.name
  virtual_network_name = azurerm_virtual_network.vnet.name

  delegation = {
    name = "Microsoft.Web.serverFarms"
    service_delegation = {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }

  service_endpoints = [
    "Microsoft.Storage",
    "Microsoft.Web",
  ]
}

module "subnet_cms_inbound" {
  source                                         = "git::https://github.com/pagopa/azurerm.git//subnet?ref=v1.0.7"
  name                                           = format("%s-cms-subnet-inbound", local.project)
  address_prefixes                               = var.cidr_subnet_cms_inbound
  resource_group_name                            = azurerm_resource_group.rg_vnet.name
  virtual_network_name                           = azurerm_virtual_network.vnet.name
  service_endpoints                              = ["Microsoft.Web"]
  enforce_private_link_endpoint_network_policies = true
}

module "azdoa_snet" {
  source                                         = "git::https://github.com/pagopa/azurerm.git//subnet?ref=v1.0.7"
  count                                          = var.enable_azdoa ? 1 : 0
  name                                           = format("%s-azdoa-snet", local.project)
  address_prefixes                               = var.cidr_subnet_azdoa
  resource_group_name                            = azurerm_resource_group.rg_vnet.name
  virtual_network_name                           = azurerm_virtual_network.vnet.name
  enforce_private_link_endpoint_network_policies = true
}
