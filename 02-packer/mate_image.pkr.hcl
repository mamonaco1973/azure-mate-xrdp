# ==============================================================================
# Packer Build: Lubuntu Image for Azure (Ubuntu 24.04 LTS)
#------------------------------------------------------------------------------
# Purpose:
#   - Builds a custom Azure Managed Image with Lubuntu and XRDP
#   - Starts from Canonical Ubuntu 24.04 LTS
#   - Installs desktop env, tools, browsers, and dev utilities
#   - Produces a timestamped image for VM or VMSS deployments
# ==============================================================================

# ------------------------------------------------------------------------------
# Packer Plugin Configuration
# - Loads the Azure plugin used for building managed images
# ------------------------------------------------------------------------------
packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~> 2"
    }
  }
}

# ------------------------------------------------------------------------------
# Locals: Timestamp Utility
# - Generates compact timestamp for image naming
# ------------------------------------------------------------------------------
locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

# ------------------------------------------------------------------------------
# Required Variables: Azure Credentials and Settings
# - Passed securely via env vars or CLI
# ------------------------------------------------------------------------------
variable "client_id" {
  description = "Azure Client ID"
  type        = string
}

variable "client_secret" {
  description = "Azure Client Secret"
  type        = string
}

variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "tenant_id" {
  description = "Azure Tenant ID"
  type        = string
}

variable "resource_group" {
  description = "Resource group for the image"
  type        = string
}

variable "location" {
  description = "Azure region to build in"
  type        = string
  default     = "Central US"
}

variable "vm_size" {
  description = "Builder VM size"
  type        = string
  default     = "Standard_D4s_v3"
}

# ------------------------------------------------------------------------------
# Source Block: Azure Image Builder
# - Defines base Ubuntu image and build parameters
# ------------------------------------------------------------------------------
source "azure-arm" "mate_image" {
  client_id       = var.client_id
  client_secret   = var.client_secret
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id

  image_publisher = "Canonical"
  image_offer     = "ubuntu-24_04-lts"
  image_sku       = "server"
  image_version   = "latest"

  location        = var.location
  vm_size         = var.vm_size
  os_type         = "Linux"
  ssh_username    = "ubuntu"

  managed_image_name = "mate_image_${local.timestamp}"
  managed_image_resource_group_name = var.resource_group
}

# ------------------------------------------------------------------------------
# Build Block: Provisioning Scripts
# - Executes each setup script inside the build VM
# ------------------------------------------------------------------------------
build {
  sources = ["source.azure-arm.mate_image"]

  # Base packages
  provisioner "shell" {
    script          = "./packages.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # MATE desktop
  provisioner "shell" {
    script          = "./mate.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # XRDP
  provisioner "shell" {
    script          = "./xrdp.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # Chrome
  provisioner "shell" {
    script          = "./chrome.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # Firefox
  provisioner "shell" {
    script          = "./firefox.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # VS Code
  provisioner "shell" {
    script          = "./vscode.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # HashiCorp tools
  provisioner "shell" {
    script          = "./hashicorp.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # AWS CLI
  provisioner "shell" {
    script          = "./awscli.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # Azure CLI
  provisioner "shell" {
    script          = "./azcli.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # Google Cloud CLI
  provisioner "shell" {
    script          = "./gcloudcli.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # Docker
  provisioner "shell" {
    script          = "./docker.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # Postman
  provisioner "shell" {
    script          = "./postman.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # KRDC
  provisioner "shell" {
    script          = "./krdc.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # OnlyOffice
  provisioner "shell" {
    script          = "./onlyoffice.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # Desktop icons
  provisioner "shell" {
    script          = "./desktop.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }
}
