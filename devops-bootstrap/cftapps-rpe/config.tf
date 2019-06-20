locals {
  common_tags = {
    "managedBy"          = "Platform Engineering"
    "solutionOwner"      = "CFT"
    "activityName"       = "AKS"
    "dataClassification" = "internal"
    "automation"         = ""
    "costCentre"         = "10245117"             // until we get a better one, this is the generic cft contingency one
    "environment"        = "rpe"
    "criticality"        = "Low"
  }
}

variable "resource_groups_resource_id" {
  default = "/subscriptions/a5453007-c32b-4336-9c79-3f643d817aea/resourceGroups/"
}

data "azurerm_resource_group" "core-infra" {

  name     = "core-infra-rpe-rg"
}

data "azurerm_key_vault" "cftapps-kv" {

  name                = "cftapps-rpe"
  resource_group_name = "${data.azurerm_resource_group.core-infra.name}"
}

data "azurerm_key_vault_secret" "cftapps-sp-object-id" {

  name         = "sp-object-id"
  key_vault_id = "${data.azurerm_key_vault.cftapps-kv.id}"
}

data "azurerm_key_vault_secret" "cftapps-aks-sp-object-id" {

  name         = "aks-sp-object-id"
  key_vault_id = "${data.azurerm_key_vault.cftapps-kv.id}"
}
