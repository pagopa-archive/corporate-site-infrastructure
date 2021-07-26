env_short       = "d"
env_long        = "development"
prefix          = "ppacorpsite"
ad_group_prefix = "sitecorporate"
tags = {
  CreatedBy   = "Terraform"
  Environment = "Dev"
  Owner       = "site-corporate"
  Source      = "https://github.com/pagopa/corporate-site-infrastructure"
  CostCenter  = ""
}
public_hostname            = "https://ppacorpsite-d-portal-backend.azurewebsites.net"
dns_zone_prefix            = "dev.ppascorp"
external_domain            = "justbit.it"
db_sku_name                = "GP_Gen5_4"
db_version                 = "5.7"
db_storage_mb              = "5120"
db_collation               = "utf8_unicode_ci"
db_ssl_enforcement_enabled = true
cms_env                    = "development"
database_name              = "ppawp"
cidr_vnet                  = ["10.0.0.0/16"]
cidr_subnet_db             = ["10.0.1.0/24"]
cidr_subnet_cms            = ["10.0.2.0/24"]
cidr_subnet_public         = ["10.0.3.0/24"]
cidr_subnet_azdoa          = ["10.0.5.0/24"]

