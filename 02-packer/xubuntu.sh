#!/bin/bash
set -euo pipefail

# ================================================================================
# Xubuntu Minimal Desktop + XFCE Enhancements Installation Script
# ================================================================================

# ================================================================================
# Step 1: Install Xubuntu minimal desktop environment
# ================================================================================

sudo apt-get update -y
sudo apt-get install -y xubuntu-desktop-minimal

# ================================================================================
# Step 1B: REMOVE NETWORKMANAGER (Critical for Azure Stability)
# ================================================================================
# Xubuntu pulls in NetworkManager. Azure cannot use it reliably — it conflicts
# with cloud-init and prevents NIC initialization after reboot.

sudo apt-get remove --purge -y network-manager
sudo apt-get autoremove -y

# ================================================================================
# Step 1C: PREVENT NETWORKMANAGER FROM EVER BEING REINSTALLED
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
# Step 2: Install clipboard utilities and XFCE enhancements
# ================================================================================

sudo apt-get install -y \
  xfce4-clipman \
  xfce4-clipman-plugin \
  xsel \
  xclip

sudo apt-get install -y \
  xfce4-terminal \
  xfce4-goodies \
  xdg-utils


# ================================================================================
# Step 3: Set XFCE Terminal as the system-wide default terminal emulator
# ================================================================================

sudo update-alternatives --install \
  /usr/bin/x-terminal-emulator \
  x-terminal-emulator \
  /usr/bin/xfce4-terminal \
  50


# ================================================================================
# Step 4: Ensure new users receive a Desktop folder
# ================================================================================

sudo mkdir -p /etc/skel/Desktop


# ================================================================================
# Step 5: Replace default XFCE background image
# ================================================================================

cd /usr/share/backgrounds/xfce

# Backup original wallpaper for safety
sudo mv xfce-shapes.svg xfce-shapes.svg.bak

# Replace with an existing, stable wallpaper
sudo cp xfce-leaves.svg xfce-shapes.svg


# ================================================================================
# Completed
# ================================================================================

echo "NOTE: Xubuntu minimal desktop + Azure-safe networking configuration complete."
