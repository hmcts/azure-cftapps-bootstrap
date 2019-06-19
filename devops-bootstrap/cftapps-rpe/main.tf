provider "azurerm" {
  version = "=1.29.0"
}

terraform {
  backend "azurerm" {
    storage_account_name = "cftappsrpe"
    container_name       = "tfstate"
    key                  = "rpe.tfstate"
  }
}

resource "azurerm_resource_group" "managed-identities" {

  name     = "managed-identities-rpe-rg"
  location = "UK South"

  tags = "${local.common_tags}"
}

resource "azurerm_role_assignment" "managed-identities-operator" {

  scope                = "${azurerm_resource_group.managed-identities.id}"
  role_definition_name = "Managed Identity Operator"
  principal_id         = "${data.azurerm_key_vault_secret.cftapps-aks-sp-object-id.value}"
}

resource "azurerm_role_assignment" "hmctsrpe-registry-pull" {

  scope                = "/subscriptions/a5453007-c32b-4336-9c79-3f643d817aea/resourceGroups/rpedev-acr"
  role_definition_name = "AcrPull"
  principal_id         = "${data.azurerm_key_vault_secret.cftapps-aks-sp-object-id.value}"
}

resource "azurerm_resource_group" "core-infra" {

  name     = "core-infra-rpe-rg"
  location = "UK South"

  tags = "${local.common_tags}"
}

resource "azurerm_role_assignment" "core-infra" {

  scope                = "${var.resource_groups_resource_id}${azurerm_resource_group.core-infra.name}"
  role_definition_name = "Contributor"
  principal_id         = "${data.azurerm_key_vault_secret.cftapps-sp-object-id.value}"
}

resource "azurerm_resource_group" "aks-infra" {

  name     = "aks-infra-rpe-rg"
  location = "UK South"

  tags = "${local.common_tags}"
}

resource "azurerm_role_assignment" "aks-infra" {

  scope                = "${var.resource_groups_resource_id}${azurerm_resource_group.aks-infra.name}"
  role_definition_name = "Contributor"
  principal_id         = "${data.azurerm_key_vault_secret.cftapps-sp-object-id.value}"
}

output "identity_rg_name" {
  value = "${azurerm_resource_group.managed-identities.name}"
}
