variable "location" {
  type        = string
  description = "Azure recourse location"
}

variable "rsv_name" {
  type        = string
  description = "Name for Recovery Service Vault"
}

variable "subscription_id" {
  type        = string
  description = "ID of Azure subscription in which RSV will be created"
}

variable "subscription_name" {
  type        = string
  description = "Name of Azure subscription in which RSV will be created"
}

variable "la_id" {
  type        = string
  description = "ID of common Log Analytics workspace"
}