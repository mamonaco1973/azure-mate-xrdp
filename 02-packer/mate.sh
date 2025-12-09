#!/bin/bash
set -euo pipefail

# ================================================================================
# Ubuntu 24.04 + MATE Desktop Installation Script
# ================================================================================
# Description:
#   Installs the full MATE desktop environment on Ubuntu 24.04. 
#
# Notes:
#   - Uses apt-get for stable automation behavior.
#   - Default wallpaper is applied via MATE's gsettings schema for new users.
# ================================================================================
#

# ================================================================================
# Step 1: Install the MATE desktop environment
# ================================================================================
sudo apt-get update -y
sudo apt-get install -y ubuntu-mate-desktop

# ================================================================================
# Step 2: Install MATE utilities (terminal, tools, XDG helpers)
# ================================================================================
sudo apt-get install -y \
  mate-terminal \
  mate-utils \
  xdg-utils \
  pcmanfm-qt 

# ==============================================================================./v ==
# Step 3: REMOVE NETWORKMANAGER (Critical for Azure Stability)
# ================================================================================
# Lubuntu pulls in NetworkManager. Azure cannot use it reliably — it conflicts
# with cloud-init and prevents NIC initialization after reboot.

sudo apt-get remove --purge -y network-manager
sudo apt-get autoremove -y

# ================================================================================
# Step 4: PREVENT NETWORKMANAGER FROM EVER BEING REINSTALLED
# ================================================================================

# 1. APT pinning — disallow installation entirely
sudo tee /etc/apt/preferences.d/disable-network-manager >/dev/null <<EOF
Package: network-manager
Pin: release *
Pin-Priority: -1

Package: network-manager-*
Pin: release *
Pin-Priority: -1
EOF

# 2. Mask services — belt & suspenders protection
sudo systemctl mask NetworkManager.service 2>/dev/null || true
sudo systemctl mask NetworkManager-wait-online.service 2>/dev/null || true

# ================================================================================
# Step 5: REMOVE LIBREOFFICE, It's unusable with XRDP and just bloat
# ================================================================================

sudo apt-get remove -y libreoffice* 
sudo apt-get autoremove -y
