variable "location" {
  type    = string
  default = "westeurope"
}

variable "prefix" {
  type    = string
  default = "scorp"
}

variable "ad_group_prefix" {
  type    = string
  default = "sitecorporate"
}

variable "env_short" {
  type = string
}

variable "env_long" {
  type = string
}

variable "tags" {
  type = map(any)
  default = {
    CreatedBy = "Terraform"
  }
}

variable "public_hostname" {
  type = string
}

variable "private_dns_zone" {
  type    = string
  default = "privatelink.mysql.database.azure.com"
}

# mysql
# variable "db_administrator_login" {
#   type        = string
#   description = "The Administrator Login for the MySQL Server."
#   sensitive   = true
# }

# variable "db_administrator_login_password" {
#   type        = string
#   description = "The Password associated with the administrator_login."
#   sensitive   = true
# }

variable "db_sku_name" {
  type        = string
  description = "Specifies the SKU Name for this MySQL Server."
}

variable "cms_env" {
  type        = string
  description = "CMS environments: development, staging or production"
}

variable "db_version" {
  type        = string
  description = "Specifies the version of MySQL to use."
}

variable "db_auto_grow_enabled" {
  type        = bool
  description = " Enable/Disable auto-growing of the storage. Storage auto-grow prevents your server from running out of storage and becoming read-only. If storage auto grow is enabled, the storage automatically grows without impacting the workload."
  default     = true
}

variable "db_backup_retention_days" {
  type        = number
  description = "Backup retention days for the server"
  default     = null
}

variable "db_create_mode" {
  type        = string
  description = "The creation mode. Can be used to restore or replicate existing servers."
  default     = "Default"
}

variable "db_public_network_access_enabled" {
  type        = bool
  description = "Whether or not public network access is allowed for this server."
  default     = false
}

variable "db_ssl_enforcement_enabled" {
  type        = bool
  description = "Specifies if SSL should be enforced on connections."
  default     = true
}

variable "db_ssl_minimal_tls_version_enforced" {
  type        = string
  description = "The mimimun TLS version to support on the sever."
  default     = "TLS1_2"
}

variable "db_storage_mb" {
  type        = number
  description = " Max storage allowed for a server."
  default     = 1024 # 5GB
}

variable "database_name" {
  type        = string
  description = "Name of the database."
}

variable "db_charset" {
  type        = string
  description = "Specifies the Charset for the MySQL Database"
  default     = "utf8"
}

variable "db_collation" {
  type        = string
  description = "Specifies the Collation for the PostgreSQL Database."
  default     = "utf8_unicode_ci"
}

# variable "cms_domain_verification_id" {
#   type        = string
#   description = "CMS App Service Custom Domain Verification ID"
# }


# variable "db_monitor_metric_alert_criteria" {
#   default = {}

#   description = <<EOD
# Map of name = criteria objects, see these docs for options
# https://docs.microsoft.com/en-us/azure/azure-monitor/platform/metrics-supported#microsoftdbforpostgresqlservers
# https://docs.microsoft.com/en-us/azure/postgresql/concepts-limits#maximum-connections
# EOD

#   type = map(object({
#     # criteria.*.aggregation to be one of [Average Count Minimum Maximum Total]
#     aggregation = string
#     metric_name = string
#     # criteria.0.operator to be one of [Equals NotEquals GreaterThan GreaterThanOrEqual LessThan LessThanOrEqual]
#     operator  = string
#     threshold = number
#     # Possible values are PT1M, PT5M, PT15M, PT30M and PT1H
#     frequency = string
#     # Possible values are PT1M, PT5M, PT15M, PT30M, PT1H, PT6H, PT12H and P1D.
#     window_size = string

#     dimension = map(object({
#       name     = string
#       operator = string
#       values   = list(string)
#     }))
#   }))
# }

## Azure container registry
variable "sku_container_registry" {
  type    = string
  default = "Basic"
}

variable "retention_policy_acr" {
  type = object({
    days    = number
    enabled = bool
  })
  default = {
    days    = 7
    enabled = true
  }
  description = "Container registry retention policy."
}


# BACKEND
variable "backend_sku" {
  type = object({
    tier     = string
    size     = string
    capacity = number
  })
  default = {
    tier     = "Standard"
    size     = "S2"
    capacity = 1
  }
}


# Network
variable "cidr_vnet" {
  type = list(string)
}

variable "cidr_subnet" {
  type = list(string)
}

variable "cidr_subnet_db" {
  type = list(string)
}

variable "cidr_subnet_public" {
  type = list(string)
}

variable "cidr_subnet_wp" {
  type = list(string)
}

variable "cidr_subnet_vpn" {
  type        = list(string)
  description = "VPN network address space."
}

variable "cidr_subnet_dnsforwarder" {
  type        = list(string)
  description = "DNS Forwarder network address space."
}

# storage
variable "storage_account_versioning" {
  type        = bool
  description = "Enable versioning in the blob storage account."
  default     = true
}

variable "storage_account_lock" {
  type = object({
    lock_level = string
    notes      = string
    scope      = string
  })
  default = null
}

variable "storage_account_website_lock" {
  type = object({
    lock_level = string
    notes      = string
    scope      = string
  })
  default = null
}


## Monitor
variable "law_sku" {
  type        = string
  description = "Sku of the Log Analytics Workspace"
  default     = "PerGB2018"
}

variable "law_retention_in_days" {
  type        = number
  description = "The workspace data retention in days"
  default     = 30
}

variable "law_daily_quota_gb" {
  type        = number
  description = "The workspace daily quota for ingestion in GB."
  default     = -1
}

# Azure DevOps Agent
variable "enable_azdoa" {
  type        = bool
  description = "Enable Azure DevOps agent."
  default     = false
}

variable "cidr_subnet_azdoa" {
  type        = list(string)
  description = "Azure DevOps agent network address space."
}

## Public DNS Zone ##
variable "dns_zone_prefix" {
  type        = string
  default     = null
  description = "The dns subdomain."
}

variable "external_domain" {
  type        = string
  default     = null
  description = "Domain for delegation"
}

variable "dns_default_ttl_sec" {
  type        = number
  description = "value"
  default     = 3600
}

# key vault

variable "devops_service_connection_object_id" {
  type        = string
  description = "Azure deveops service connection id."
  default     = null
}

variable "azuread_service_principal_web_app_resource_provider_id" {
  type        = string
  description = "WebApp Service Resource Principal ID https://github.com/terraform-providers/terraform-provider-azurerm/blob/master/examples/app-service-certificate/stored-in-keyvault/main.tf#L33"
  # this is the deafult value for tenant pagopa.it
  default = "bb319217-f6ab-45d9-833d-555ef1173316"
}

variable "azuread_service_principal_azure_cdn_frontdoor_id" {
  type        = string
  description = "Azure CDN Front Door Principal ID"
  # this is the deafult value for tenant pagopa.it
  default = "f3b3f72f-4770-47a5-8c1e-aa298003be12"
}

## VPN ##
variable "vpn_sku" {
  type        = string
  default     = "VpnGw1"
  description = "VPN Gateway SKU"
}

variable "vpn_pip_sku" {
  type        = string
  default     = "Basic"
  description = "VPN GW PIP SKU"
}
