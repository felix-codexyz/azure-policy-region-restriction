variable "subscription_id" {
  type        = string
  description = "The Azure subscription ID where the policy will be assigned"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}
