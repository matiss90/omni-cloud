resource "azurerm_resource_group" "backup" {
  name     = "backup"
  location = var.location
}

resource "azurerm_log_analytics_workspace" "backup" {
  name                = "Backup"
  location            = var.location
  resource_group_name = azurerm_resource_group.backup.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_monitor_action_group" "backup_failed" {
  name                = "BackupFailedAlert"
  resource_group_name = azurerm_resource_group.backup.name
  short_name          = "BackupAlert"

  email_receiver {
    name          = "support"
    email_address = "support@example.com"
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert" "backup_job_failed" {
  name                = "Backup - failed job"
  location            = var.location
  resource_group_name = azurerm_resource_group.backup.name

  action {
    action_group  = [azurerm_monitor_action_group.backup_failed.id]
    email_subject = "[Alert] Backup job failure"
  }

  data_source_id      = azurerm_log_analytics_workspace.backup.id
  description         = "Alert when there is backup job failure"
  enabled             = true
  query               = <<-QUERY
    AddonAzureBackupJobs
    | where JobOperation=="Backup"
    | summarize arg_max(TimeGenerated,*) by JobUniqueId
    | where JobStatus=="Failed" and not(JobFailureCode=="OperationCancelledBecauseConflictingOperationRunningUserError")
  QUERY
  severity            = 1
  frequency           = 1440
  time_window         = 1440
  trigger {
    operator  = "GreaterThan"
    threshold = 0
  }
}

module "rsv" {
  source            = "./modules/rsv"
  subscription_id   = var.subscription_id
  subscription_name = var.subscription_name
  location          = var.location
  rsv_name          = "${var.subscription_name}-rsv"
  la_id             = azurerm_log_analytics_workspace.backup.id
}
