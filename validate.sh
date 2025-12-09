#!/bin/bash
# --------------------------------------------------------------------------------
# Description:
#   Queries Azure for public IP resources in a target resource group and prints
#   their fully qualified DNS names. Replaces AWS EC2 lookups with Azure CLI.
#
# Requirements:
#   - Azure CLI installed and logged in
#   - Public IPs must exist in RG: lubuntu-project-rg
#   - Public IP resource names:
#       * windows-vm-public-ip
#       * lubuntu-public-ip
# --------------------------------------------------------------------------------

# --------------------------------------------------------------------------------
# Configuration
# --------------------------------------------------------------------------------
RESOURCE_GROUP="lubuntu-project-rg"

# --------------------------------------------------------------------------------
# Lookup Windows VM Public FQDN
# --------------------------------------------------------------------------------
windows_dns=$(az network public-ip show \
  --resource-group "$RESOURCE_GROUP" \
  --name "windows-vm-public-ip" \
  --query "dnsSettings.fqdn" \
  --output tsv 2>/dev/null)

if [ -z "$windows_dns" ]; then
  echo "ERROR: No DNS label found for windows-vm-public-ip"
else
  echo "NOTE: Windows Admin Instance FQDN: $windows_dns"
fi

# --------------------------------------------------------------------------------
# Lookup Lubuntu Public FQDN
# --------------------------------------------------------------------------------
lubuntu_dns=$(az network public-ip show \
  --resource-group "$RESOURCE_GROUP" \
  --name "lubuntu-public-ip" \
  --query "dnsSettings.fqdn" \
  --output tsv 2>/dev/null)

if [ -z "$lubuntu_dns" ]; then
  echo "ERROR: No DNS label found for lubuntu-public-ip"
else
  echo "NOTE: Lubuntu Instance FQDN: $lubuntu_dns"

  # ------------------------------------------------------------------------
  # Wait for SSH (port 22) on Lubuntu instance
  # ------------------------------------------------------------------------
  max_attempts=60
  attempt=1
  sleep_secs=10

  echo "NOTE: Waiting for SSH (port 22) on $lubuntu_dns ..."

  while [ "$attempt" -le "$max_attempts" ]; do
    if timeout 5 bash -c "echo > /dev/tcp/$lubuntu_dns/22" 2>/dev/null; then
      echo "NOTE: SSH is reachable on $lubuntu_dns:22"
      break
    fi

    echo "WARNING: Attempt $attempt/$max_attempts - SSH not ready, sleeping ${sleep_secs}s ..."
    attempt=$((attempt + 1))
    sleep "$sleep_secs"
  done

  if [ "$attempt" -gt "$max_attempts" ]; then
    echo "ERROR: Timed out waiting for SSH on $lubuntu_dns:22"
  fi
fi