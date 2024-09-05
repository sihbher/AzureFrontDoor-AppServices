variable "primary_location" {
  description = "The Azure region to deploy resources"
  default     = "eastus2"
}

variable "secondary_location" {
  description = "The Azure region to deploy resources"
  default     = "westus"
}

variable "os_type" {
  description = "The OS type for the resources"
  default     = "Linux" 
}

variable "front_door_sku_name" {
  type        = string
  description = "The SKU for the Front Door profile. Possible values include: Standard_AzureFrontDoor, Premium_AzureFrontDoor"
  default     = "Premium_AzureFrontDoor"
  validation {
    condition     = contains(["Standard_AzureFrontDoor", "Premium_AzureFrontDoor"], var.front_door_sku_name)
    error_message = "The SKU value must be one of the following: Standard_AzureFrontDoor, Premium_AzureFrontDoor."
  }
}