# Get current Azure context (subscription info)
data "azurerm_client_config" "current" {}

resource "azurerm_policy_definition" "allow_only_eastus" {
  name         = "allow-only-eastus"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Allow Only East US Region"
  description  = "Only East US region is allowed"
  policy_rule  = file("${path.module}/../policy/allow-only-eastus.json")
}

resource "azurerm_subscription_policy_assignment" "assign_policy" {
  name                 = "enforce-eastus"
  display_name         = "Enforce East US Only"
  policy_definition_id = azurerm_policy_definition.allow_only_eastus.id
  subscription_id      = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
}