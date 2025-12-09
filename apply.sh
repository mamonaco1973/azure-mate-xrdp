#!/bin/bash
# ==============================================================================
# Build Script for MATE XRDP Project on Azure
# Purpose:
#   - Validates the environment and prerequisites before deployment.
#   - Deploys the project in two phases:
#       1. Directory layer: Key Vault, Mini-AD and base infra.
#       2. Server layer: MATE VM, AD Admin VM, and secrets.
#   - Uses Packer to build the MATE image before server deployment.
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
# Build MATE image with Packer
# ------------------------------------------------------------------------------
cd 02-packer

packer init .
packer build \
 -var="client_id=$ARM_CLIENT_ID" \
 -var="client_secret=$ARM_CLIENT_SECRET" \
 -var="subscription_id=$ARM_SUBSCRIPTION_ID" \
 -var="tenant_id=$ARM_TENANT_ID" \
 -var="resource_group=mate-project-rg" \
 mate_image.pkr.hcl

cd ..

# ------------------------------------------------------------------------------
# Deploy server layer (AD Admin VM and MATE VM)
# ------------------------------------------------------------------------------
cd 03-servers

# ------------------------------------------------------------------------------
# Fetch latest MATE image from packer resource group
# ------------------------------------------------------------------------------
mate_image_name=$(az image list \
  --resource-group mate-project-rg \
  --query "[?starts_with(name, 'mate_image')]|sort_by(@, &name)[-1].name" \
  --output tsv)

echo "NOTE: Using latest MATE image: $mate_image_name"

if [ -z "$mate_image_name" ]; then
  echo "ERROR: No MATE image found in mate-project-rg."
  exit 1
fi

# ------------------------------------------------------------------------------
# Discover Key Vault created in Phase 1
# ------------------------------------------------------------------------------
vault=$(az keyvault list \
  --resource-group mate-network-rg \
  --query "[?starts_with(name, 'ad-key-vault')].name | [0]" \
  --output tsv)

echo "NOTE: Using Key Vault: $vault"

# ------------------------------------------------------------------------------
# Deploy Server layer with Terraform
# ------------------------------------------------------------------------------

terraform init
terraform apply \
  -var="vault_name=$vault" \
  -var="mate_image_name=$mate_image_name" \
  -auto-approve

cd ..

# ------------------------------------------------------------------------------
# Run Build Validation
# ------------------------------------------------------------------------------

./validate.sh
