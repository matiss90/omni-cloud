# Terraform configuration
variable "subscription_id" {
  type        = string
  description = "Azure subscription ID"
}

variable "client_id" {
  type        = string
  description = "Service principal client ID"
}

variable "client_secret" {
  type        = string
  description = "Service principal client secret"
}

variable "tenant_id" {
  type        = string
  description = "Azure Active Directory tenant ID"
}

# Environment variables
variable "location" {
  type        = string
  description = "Azure recourse location"
  default     = "westeurope"
}

variable "subscription_name" {
  type        = string
  description = "Azure subscription name"
  default     = "testsub"
}