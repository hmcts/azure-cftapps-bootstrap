resource "azurerm_resource_group" "oms-automation" {

  name     = "oms-automation-rg"
  location = "UK South"

  tags = "${local.common_tags}"
}

resource "azurerm_role_assignment" "oms-automation" {

  scope                = "${var.resource_groups_resource_id}${azurerm_resource_group.oms-automation.name}"
  role_definition_name = "Contributor"
  principal_id         = "${data.azurerm_key_vault_secret.cftapps-sp-object-id.value}"
}

resource "azurerm_log_analytics_workspace" "oms-automation" {
  name                = "hmcts-rpe-law"
  location            = "${azurerm_resource_group.oms-automation.location}"
  resource_group_name = "${azurerm_resource_group.oms-automation.name}"
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

output "oms_workspace" {
  value = "${azurerm_log_analytics_workspace.oms-automation.workspace_id}"
}
