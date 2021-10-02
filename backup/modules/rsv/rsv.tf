resource "azurerm_resource_group" "rsv" {
  name     = "${var.rsv_name}-rg"
  location = var.location
}

resource "azurerm_recovery_services_vault" "vault" {
  name                = var.rsv_name
  location            = var.location
  resource_group_name = azurerm_resource_group.rsv.name
  sku                 = "Standard"
  soft_delete_enabled = true
}

# Example default backup policy

resource "azurerm_backup_policy_vm" "daily_vm_backup" {
  name                = "vm-backup-policy-daily"
  resource_group_name = azurerm_resource_group.rsv.name
  recovery_vault_name = azurerm_recovery_services_vault.vault.name
  timezone            = "UTC"

  backup {
    frequency = "Daily"
    time      = "23:00"
  }

  retention_daily {
    count = "7"
  }

  retention_weekly {
    count    = 4
    weekdays = ["Friday"]
  }
}

# Policy for RSV diagnostic settings
resource "azurerm_subscription_policy_assignment" "rsv_diagnostics" {
  name                 = "deploy-diagnostic-settings-for-recovery-services-vault"
  subscription_id      = "/subscriptions/${var.subscription_id}"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/c717fb0c-d118-4c43-ab3d-ece30ac81fb3"
  description          = "Deploy Diagnostic Settings for Recovery Services Vault to Log Analytics workspace for resource specific categories."
  display_name         = "Deploy Diagnostic Settings for Recovery Services Vaults in ${var.subscription_name}"
  location             = var.location

  parameters = jsonencode (
    {
      "logAnalytics": {
        "value": var.la_id
      }
    }
  )

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_policy_remediation" "remediate_rsv_diagnostics" {
  name                    = "remediate-diagnostic-settings-for-recovery-services-vault"
  scope                   = azurerm_subscription_policy_assignment.rsv_diagnostics.subscription_id
  policy_assignment_id    = azurerm_subscription_policy_assignment.rsv_diagnostics.id
  resource_discovery_mode = "ReEvaluateCompliance"
}

resource "azurerm_role_assignment" "remediate_rsv_diagnostics_monitoring_contributor" {
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "Monitoring Contributor"
  principal_id         = azurerm_subscription_policy_assignment.rsv_diagnostics.identity[0].principal_id
}

resource "azurerm_role_assignment" "remediate_rsv_diagnostics_log_analytics_contributor" {
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "Log Analytics Contributor"
  principal_id         = azurerm_subscription_policy_assignment.rsv_diagnostics.identity[0].principal_id
}


# Policy to enforce presence of backup tag with boolean value
resource "azurerm_policy_definition" "require_backup_tag" {
  name         = "Require a tag and its value on VM"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Require a tag and its value on VM"

  metadata = jsonencode (
    {
    "category": "Tags"
    }
  )

  policy_rule = jsonencode (
    {
      "if": {
        "allof": [
          {
            "field": "type",
            "equals": "Microsoft.Compute/VirtualMachines"
          },
          {
            "not": {
              "field": "[concat('tags[', parameters('tagName'), ']')]",
              "in": [
                "true",
                "false"
              ]
            }
          }
        ]
      },
      "then": {
        "effect": "deny"
      }
    }
  )

  parameters = jsonencode (
    {
      "tagName": {
        "type": "String",
        "metadata": {
          "description": "Name of the tag, such as 'environment'"
          "displayName": "Tag Name",
        }
      }
    }
  )
}

resource "azurerm_subscription_policy_assignment" "require_backup_tag" {
  name                 = "Require a backup tag with boolean value on every VM"
  subscription_id      = "/subscriptions/${var.subscription_id}"
  policy_definition_id = azurerm_policy_definition.require_backup_tag.id
  description          = "Enforce backup tag with boolean value presence for all virtual machines."
  display_name         = "Audit resources for missing mandatory tag: backup"
  location             = var.location

  parameters = jsonencode (
    {
      "tagName": {
        "value": "backup"
      }
    }
  )

  identity {
    type = "SystemAssigned"
  }
}

# Policy to enable backup on VMs with backup tag with value "true"
resource "azurerm_subscription_policy_assignment" "configure_backup_on_vms_with_given_tag" {
  name                 = "Configure backup on VMs with given tag"
  subscription_id      = "/subscriptions/${var.subscription_id}"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/345fa903-145c-4fe1-8bcd-93ec2adccde8"
  description          = "Enforce backup for all virtual machines by backing them up to an existing central recovery services vault in the same location and subscription as the virtual machine. See https://aka.ms/AzureVMCentralBackupIncludeTag."
  display_name         = "Configure backup on virtual machines in ${var.subscription_name}"
  location             = var.location

  parameters = jsonencode (
    {
    "vaultLocation": {
        "value": var.location
    },
    "inclusionTagName": {
        "value": "backup"
    },
    "inclusionTagValue": {
        "value": ["true"]
    },
    "backupPolicyId": {
        "value": azurerm_backup_policy_vm.daily_vm_backup.id
    },
    "effect": {
        "value": "deployIfNotExists"
    }
    }
  )

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_policy_remediation" "remediate_vms_backup" {
  name                    = "remediate-vms-backup"
  scope                   = azurerm_subscription_policy_assignment.configure_backup_on_vms_with_given_tag.subscription_id
  policy_assignment_id    = azurerm_subscription_policy_assignment.configure_backup_on_vms_with_given_tag.id
  resource_discovery_mode = "ReEvaluateCompliance"
}

resource "azurerm_role_assignment" "remediate_vms_backup_vm_contributor" {
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azurerm_subscription_policy_assignment.configure_backup_on_vms_with_given_tag.identity[0].principal_id
}

resource "azurerm_role_assignment" "remediate_vms_backup_backup_contributor" {
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "Backup Contributor"
  principal_id         = azurerm_subscription_policy_assignment.configure_backup_on_vms_with_given_tag.identity[0].principal_id
}