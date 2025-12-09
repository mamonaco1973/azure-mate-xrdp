# ==================================================================================================
# AzureRM Provider and Core Resource Group Setup
# - Configures Azure provider features
# - Defines subscription and client data sources
# - Declares input variables for RG name and location
# - Creates the primary resource group for deployment
# ==================================================================================================

# --------------------------------------------------------------------------------------------------
# Configure AzureRM provider
# --------------------------------------------------------------------------------------------------
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true   # Purge Key Vault immediately on destroy
      recover_soft_deleted_key_vaults = false  # Do not auto-recover deleted Key Vaults
    }

    resource_group {
      prevent_deletion_if_contains_resources = false # Allow deletion of RG even if non-empty
    }
  }
}

# --------------------------------------------------------------------------------------------------
# Fetch subscription details (subscription ID, display name, etc.)
# --------------------------------------------------------------------------------------------------
data "azurerm_subscription" "primary" {}

# --------------------------------------------------------------------------------------------------
# Fetch details of the authenticated client (SPN or user identity)
# --------------------------------------------------------------------------------------------------
data "azurerm_client_config" "current" {}

# --------------------------------------------------------------------------------------------------
# Input variable: Network Resource Group name
# --------------------------------------------------------------------------------------------------
variable "network_resource_group_name" {
  description = "The name of the Azure Networking Resource Group"
  type        = string
  default     = "mate-network-rg"
}

# --------------------------------------------------------------------------------------------------
# Input variable: Network Resource Group location
# --------------------------------------------------------------------------------------------------
variable "network_group_location" {
  description = "The Azure region where the Resource Group will be created"
  type        = string
  default     = "Central US"
}

# --------------------------------------------------------------------------------------------------
# Create the Resource Group
# --------------------------------------------------------------------------------------------------
resource "azurerm_resource_group" "ad" {
  name     = var.network_resource_group_name
  location = var.network_group_location
}

# --------------------------------------------------------------------------------------------------
# Input variable: Servers Resource Group name
# --------------------------------------------------------------------------------------------------
variable "servers_resource_group_name" {
  description = "The name of the Azure Servers Resource Group"
  type        = string
  default     = "mate-project-rg"
}

# --------------------------------------------------------------------------------------------------
# Input variable: Servers Resource Group location
# --------------------------------------------------------------------------------------------------
variable "servers_group_location" {
  description = "The Azure region where the Resource Group will be created"
  type        = string
  default     = "Central US"
}

# --------------------------------------------------------------------------------------------------
# Create the Resource Group
# --------------------------------------------------------------------------------------------------
resource "azurerm_resource_group" "servers" {
  name     = var.servers_resource_group_name
  location = var.servers_group_location
}
