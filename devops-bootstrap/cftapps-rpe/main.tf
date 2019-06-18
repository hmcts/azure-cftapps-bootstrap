provider "azurerm" {
  version = "=1.29.0"
}

terraform {
  backend "azurerm" {}
}

resource "azurerm_resource_group" "managed-identities" {
  provider = "azurerm.cftapps-rpe"

  name     = "managed-identities-rpe-rg"
  location = "UK South"

  tags = "${local.common_tags}"
}

resource "azurerm_role_assignment" "managed-identities-operator" {
  provider = "azurerm.cftapps-rpe"

  scope                = "${var.resource_groups_resource_id}${azurerm_resource_group.managed-identities.name}"
  role_definition_name = "Managed Identity Operator"
  principal_id         = "${data.azurerm_key_vault_secret.cftapps-aks-sp-object-id.value}"
}

resource "azurerm_role_assignment" "hmctsrpe-registry-pull" {
  provider = "azurerm.cft-rpe"

  scope                = "/subscriptions/a5453007-c32b-4336-9c79-3f643d817aea/resourceGroups/rpedev-acr"
  role_definition_name = "AcrPull"
  principal_id         = "${data.azurerm_key_vault_secret.cftapps-aks-sp-object-id.value}"
}

resource "azurerm_resource_group" "core-infra" {
  provider = "azurerm.cftapps-rpe"

  name     = "core-infra-rpe-rg"
  location = "UK South"

  tags = "${local.common_tags}"
}

resource "azurerm_role_assignment" "core-infra" {
  provider = "azurerm.cftapps-rpe"

  scope                = "${var.resource_groups_resource_id}${azurerm_resource_group.core-infra.name}"
  role_definition_name = "Contributor"
  principal_id         = "${data.azurerm_key_vault_secret.cftapps-sp-object-id.value}"
}

resource "azurerm_resource_group" "aks-infra" {
  provider = "azurerm.cftapps-rpe"

  name     = "aks-infra-sbox-rg"
  location = "UK South"

  tags = "${local.common_tags}"
}

resource "azurerm_role_assignment" "aks-infra" {
  provider = "azurerm.cftapps-rpe"

  scope                = "${var.resource_groups_resource_id}${azurerm_resource_group.aks-infra.name}"
  role_definition_name = "Contributor"
  principal_id         = "${data.azurerm_key_vault_secret.cftapps-sp-object-id.value}"
}

output "identity_rg_name" {
  value = "${azurerm_resource_group.managed-identities.name}"
}
