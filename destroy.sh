#!/bin/bash
# ==============================================================================
# Destroy Script for Lubuntu XRDP Project on Azure
# Purpose:
#   - Removes all Lubuntu XRDP project resources deployed in Azure.
#   - Destroys server layer first, then directory layer.
#   - Deletes the latest Lubuntu image and all older images.
# Notes:
#   - This will permanently delete all deployed resources.
#   - Assumes Azure CLI and Terraform are installed and authenticated.
# ==============================================================================

set -e

# ------------------------------------------------------------------------------
# Fetch latest Lubuntu image from the packer resource group
# ------------------------------------------------------------------------------
lubuntu_image_name=$(az image list \
  --resource-group lubuntu-project-rg \
  --query "[?starts_with(name, 'lubuntu_image')]|sort_by(@, &name)[-1].name" \
  --output tsv)

echo "NOTE: Using latest image: $lubuntu_image_name"

if [ -z "$lubuntu_image_name" ]; then
  echo "ERROR: No Lubuntu image found in lubuntu-project-rg."
  exit 1
fi

# ------------------------------------------------------------------------------
# Phase 1: Destroy server layer (VMs, networking, bindings)
# ------------------------------------------------------------------------------
cd 03-servers

vault=$(az keyvault list \
  --resource-group lubuntu-network-rg \
  --query "[?starts_with(name, 'ad-key-vault')].name | [0]" \
  --output tsv)

echo "NOTE: Using Key Vault: $vault"

terraform init
terraform destroy \
  -var="vault_name=$vault" \
  -var="lubuntu_image_name=$lubuntu_image_name" \
  -auto-approve

cd ..

# ------------------------------------------------------------------------------
# Delete all Lubuntu images in lubuntu-project-rg
# ------------------------------------------------------------------------------
az image list \
  --resource-group lubuntu-project-rg \
  --query "[].name" \
  -o tsv | while read -r IMAGE; do
    echo "Deleting image: $IMAGE"
    az image delete \
      --name "$IMAGE" \
      --resource-group lubuntu-project-rg \
      || echo "Failed to delete $IMAGE; skipping"
done

# ------------------------------------------------------------------------------
# Phase 2: Destroy directory layer (Key Vault, baseline infra)
# ------------------------------------------------------------------------------
cd 01-directory

terraform init
terraform destroy -auto-approve

cd ..
echo "NOTE: Lubuntu XRDP project resources have been successfully destroyed."