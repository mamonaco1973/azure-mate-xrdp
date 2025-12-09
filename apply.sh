#!/bin/bash
# ==============================================================================
# Build Script for Lubuntu XRDP Project on Azure
# Purpose:
#   - Validates the environment and prerequisites before deployment.
#   - Deploys the project in two phases:
#       1. Directory layer: Key Vault, Mini-AD and base infra.
#       2. Server layer: Lubuntu VM, AD Admin VM, and secrets.
#   - Uses Packer to build the Lubuntu image before server deployment.
# Notes:
#   - Assumes Azure CLI and Terraform are installed and logged in.
#   - Assumes check_env.sh validates required vars and tools.
#   - Key Vault name created in Phase 1 is auto-discovered for Phase 2.
# ==============================================================================

set -e

# ------------------------------------------------------------------------------
# Pre-flight check: validate environment with check_env.sh
# ------------------------------------------------------------------------------
./check_env.sh
if [ $? -ne 0 ]; then
  echo "ERROR: Environment check failed."
  exit 1
fi

# ------------------------------------------------------------------------------
# Deploy directory layer (Mini-AD, Key Vault and base infra)
# ------------------------------------------------------------------------------
cd 01-directory

terraform init
terraform apply -auto-approve
if [ $? -ne 0 ]; then
  echo "ERROR: Terraform apply failed in 01-directory."
  exit 1
fi

cd ..

# ------------------------------------------------------------------------------
# Build Lubuntu image with Packer
# ------------------------------------------------------------------------------
cd 02-packer

packer init .
packer build \
 -var="client_id=$ARM_CLIENT_ID" \
 -var="client_secret=$ARM_CLIENT_SECRET" \
 -var="subscription_id=$ARM_SUBSCRIPTION_ID" \
 -var="tenant_id=$ARM_TENANT_ID" \
 -var="resource_group=lubuntu-project-rg" \
 lubuntu_image.pkr.hcl

cd ..

# ------------------------------------------------------------------------------
# Deploy server layer (AD Admin VM and Lubuntu VM)
# ------------------------------------------------------------------------------
cd 03-servers

# ------------------------------------------------------------------------------
# Fetch latest Lubuntu image from packer resource group
# ------------------------------------------------------------------------------
lubuntu_image_name=$(az image list \
  --resource-group lubuntu-project-rg \
  --query "[?starts_with(name, 'lubuntu_image')]|sort_by(@, &name)[-1].name" \
  --output tsv)

echo "NOTE: Using latest Lubuntu image: $lubuntu_image_name"

if [ -z "$lubuntu_image_name" ]; then
  echo "ERROR: No Lubuntu image found in lubuntu-project-rg."
  exit 1
fi

# ------------------------------------------------------------------------------
# Discover Key Vault created in Phase 1
# ------------------------------------------------------------------------------
vault=$(az keyvault list \
  --resource-group lubuntu-network-rg \
  --query "[?starts_with(name, 'ad-key-vault')].name | [0]" \
  --output tsv)

echo "NOTE: Using Key Vault: $vault"

# ------------------------------------------------------------------------------
# Deploy Server layer with Terraform
# ------------------------------------------------------------------------------

terraform init
terraform apply \
  -var="vault_name=$vault" \
  -var="lubuntu_image_name=$lubuntu_image_name" \
  -auto-approve

cd ..

# ------------------------------------------------------------------------------
# Run Build Validation
# ------------------------------------------------------------------------------

./validate.sh
