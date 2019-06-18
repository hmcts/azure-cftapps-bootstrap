resource "azurerm_resource_group" "rpe-00-rg" {
  provider = "azurerm.cftapps-rpe"

  name     = "rpe-00-rg"
  location = "UK South"

  tags = "${local.common_tags}"
}

resource "azurerm_role_assignment" "rpe-00-rg" {
  provider = "azurerm.cftapps-rpe"

  scope                = "${var.resource_groups_resource_id}${azurerm_resource_group.rpe-00-rg.name}"
  role_definition_name = "Contributor"
  principal_id         = "${data.azurerm_key_vault_secret.cftapps-sp-object-id.value}"
}

resource "azurerm_resource_group" "rpe-01-rg" {
  provider = "azurerm.cftapps-rpe"

  name     = "rpe-01-rg"
  location = "UK South"

  tags = "${local.common_tags}"
}

resource "azurerm_role_assignment" "rpe-01-rg" {
  provider = "azurerm.cftapps-rpe"

  scope                = "${var.resource_groups_resource_id}${azurerm_resource_group.rpe-01-rg.name}"
  role_definition_name = "Contributor"
  principal_id         = "${data.azurerm_key_vault_secret.cftapps-sp-object-id.value}"
}

resource "azurerm_role_assignment" "network-contributor" {
  provider = "azurerm.cftapps-rpe"

  scope                = "${var.resource_groups_resource_id}aks-infra-rpe-rg"
  role_definition_name = "Network Contributor"
  principal_id         = "${data.azurerm_key_vault_secret.cftapps-aks-sp-object-id.value}"
}
