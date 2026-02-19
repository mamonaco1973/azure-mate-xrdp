#!/bin/bash
# ==============================================================================
# validate.sh - MATE Quick Start Validation (Azure)
# ------------------------------------------------------------------------------
# Purpose:
#   - Queries Azure for expected MATE Quick Start Public IP resources and prints
#     quick-start endpoints for copy/paste access.
#
# Scope:
#   - Looks up Public IP DNS FQDNs created by Terraform:
#       - Windows admin host (management / test client): windows-vm-public-ip
#       - MATE desktop host: mate-public-ip
#
# Fast-Fail Behavior:
#   - Script exits immediately on command failure, unset variables,
#     or failed pipelines.
#
# Requirements:
#   - Azure CLI installed and authenticated (az login).
#   - Resources deployed in the expected resource group.
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------
RESOURCE_GROUP="mate-project-rg"

WINDOWS_PIP_NAME="windows-vm-public-ip"
MATE_PIP_NAME="mate-public-ip"

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------
az_trim() {
  # Trims whitespace/newlines from az output.
  xargs 2>/dev/null || true
}

get_public_fqdn_by_pip_name() {
  local rg="$1"
  local pip_name="$2"

  az network public-ip show \
    --resource-group "${rg}" \
    --name "${pip_name}" \
    --query "dnsSettings.fqdn" \
    --output tsv 2>/dev/null | az_trim
}

# ------------------------------------------------------------------------------
# Lookups
# ------------------------------------------------------------------------------
windows_fqdn="$(get_public_fqdn_by_pip_name "${RESOURCE_GROUP}" "${WINDOWS_PIP_NAME}")"
mate_fqdn="$(get_public_fqdn_by_pip_name "${RESOURCE_GROUP}" "${MATE_PIP_NAME}")"

# ------------------------------------------------------------------------------
# Quick Start Output
# ------------------------------------------------------------------------------
echo ""
echo "============================================================================"
echo "MATE Quick Start - Validation Output (Azure)"
echo "============================================================================"
echo ""

printf "%-28s %s\n" "NOTE: Resource Group:" "${RESOURCE_GROUP}"
echo ""

if [ -z "${windows_fqdn}" ]; then
  printf "%-28s %s\n" "ERROR: Windows RDP Host:" \
    "No FQDN found (Public IP: ${WINDOWS_PIP_NAME})"
else
  printf "%-28s %s\n" "NOTE: Windows RDP Host:" "${windows_fqdn}"
fi

if [ -z "${mate_fqdn}" ]; then
  printf "%-28s %s\n" "ERROR: MATE Host:" \
    "No FQDN found (Public IP: ${MATE_PIP_NAME})"
  echo ""
  exit 1
fi

printf "%-28s %s\n" "NOTE: MATE Host:" "${mate_fqdn}"
echo ""