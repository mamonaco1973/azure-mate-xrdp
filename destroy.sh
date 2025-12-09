#!/bin/bash
# ==============================================================================
# Destroy Script for Mate XRDP Project on Azure
# Purpose:
#   - Removes all Mate XRDP project resources deployed in Azure.
#   - Destroys server layer first, then directory layer.
#   - Deletes the latest Mate image and all older images.
# Notes:
#   - This will permanently delete all deployed resources.
#   - Assumes Azure CLI and Terraform are installed and authenticated.
# ==============================================================================

set -e

# ------------------------------------------------------------------------------
# Fetch latest Mate image from the packer resource group
# ------------------------------------------------------------------------------
mate_image_name=$(az image list \
  --resource-group mate-project-rg \
  --query "[?starts_with(name, 'mate_image')]|sort_by(@, &name)[-1].name" \
  --output tsv)

echo "NOTE: Using latest image: $mate_image_name"

if [ -z "$mate_image_name" ]; then
  echo "ERROR: No Mate image found in mate-project-rg."
  exit 1
fi

# ------------------------------------------------------------------------------
# Phase 1: Destroy server layer (VMs, networking, bindings)
# ------------------------------------------------------------------------------
cd 03-servers

vault=$(az keyvault list \
  --resource-group mate-network-rg \
  --query "[?starts_with(name, 'ad-key-vault')].name | [0]" \
  --output tsv)

echo "NOTE: Using Key Vault: $vault"

terraform init
terraform destroy \
  -var="vault_name=$vault" \
  -var="mate_image_name=$mate_image_name" \
  -auto-approve

cd ..

# ------------------------------------------------------------------------------
# Delete all Mate images in mate-project-rg
# ------------------------------------------------------------------------------
az image list \
  --resource-group mate-project-rg \
  --query "[].name" \
  -o tsv | while read -r IMAGE; do
    echo "Deleting image: $IMAGE"
    az image delete \
      --name "$IMAGE" \
      --resource-group mate-project-rg \
      || echo "Failed to delete $IMAGE; skipping"
done

# ------------------------------------------------------------------------------
# Phase 2: Destroy directory layer (Key Vault, baseline infra)
# ------------------------------------------------------------------------------
cd 01-directory

terraform init
terraform destroy -auto-approve

cd ..
echo "NOTE: Mate XRDP project resources have been successfully destroyed."