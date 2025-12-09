# ==============================================================================
# AzureRM provider configuration and core data sources
# ------------------------------------------------------------------------------
# Configures the AzureRM provider, defines key input variables, and loads core
# data sources including subscription info, client config, resource groups,
# virtual network, subnet, Key Vault, and custom VM image details.
# ==============================================================================

# ------------------------------------------------------------------------------
# Configure AzureRM provider for all Azure deployments
# ------------------------------------------------------------------------------
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true  # Purge Key Vaults on destroy
      recover_soft_deleted_key_vaults = false # Do not auto-recover deleted vaults
    }
  }
}

# ------------------------------------------------------------------------------
# Subscription details for the authenticated Azure context
# ------------------------------------------------------------------------------
data "azurerm_subscription" "primary" {}

# ------------------------------------------------------------------------------
# Client configuration details (SPN or user identity)
# ------------------------------------------------------------------------------
data "azurerm_client_config" "current" {}

# ------------------------------------------------------------------------------
# Input variable: resource group for core project resources
# ------------------------------------------------------------------------------
variable "resource_group_name" {
  description = "Name of the Azure Resource Group for the project"
  type        = string
  default     = "mate-project-rg"
}

# ------------------------------------------------------------------------------
# Input variable: resource group containing network resources
# ------------------------------------------------------------------------------
variable "network_resource_group_name" {
  description = "Name of the Resource Group for networking resources"
  type        = string
  default     = "mate-network-rg"
}

# ------------------------------------------------------------------------------
# Input variable: Key Vault name used to store secrets
# ------------------------------------------------------------------------------
variable "vault_name" {
  description = "Name of the Azure Key Vault for storing secrets"
  type        = string
}

# ------------------------------------------------------------------------------
# Load details for the main project resource group
# ------------------------------------------------------------------------------
data "azurerm_resource_group" "mate" {
  name = var.resource_group_name
}

# ------------------------------------------------------------------------------
# Load details for the networking resource group
# ------------------------------------------------------------------------------
data "azurerm_resource_group" "network" {
  name = var.network_resource_group_name
}

# ------------------------------------------------------------------------------
# Load details of the existing virtual network
# ------------------------------------------------------------------------------
data "azurerm_virtual_network" "ad_vnet" {
  name                = "ad-vnet"
  resource_group_name = data.azurerm_resource_group.network.name
}

# ------------------------------------------------------------------------------
# Load details of the VM subnet inside the VNet
# ------------------------------------------------------------------------------
data "azurerm_subnet" "vm_subnet" {
  name                 = "vm-subnet"
  resource_group_name  = data.azurerm_resource_group.network.name
  virtual_network_name = data.azurerm_virtual_network.ad_vnet.name
}

# ------------------------------------------------------------------------------
# Load Key Vault details for storing VM and service credentials
# ------------------------------------------------------------------------------
data "azurerm_key_vault" "ad_key_vault" {
  name                = var.vault_name
  resource_group_name = var.network_resource_group_name
}

# ------------------------------------------------------------------------------
# Input variable: name of the custom MATE image in Azure
# ------------------------------------------------------------------------------
variable "mate_image_name" {
  description = "Name of the custom Azure Linux image"
  type        = string
}

# ------------------------------------------------------------------------------
# Load custom MATE image from the resource group
# ------------------------------------------------------------------------------
data "azurerm_image" "mate_image" {
  name                = var.mate_image_name
  resource_group_name = data.azurerm_resource_group.mate.name
}
