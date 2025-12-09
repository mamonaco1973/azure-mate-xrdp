#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# ==============================================================================
# Lubuntu Cloud Edition Installation Script (Minimal LXQt Desktop)
# ==============================================================================
# Description:
#   Installs a lightweight LXQt desktop environment suitable for cloud VMs and
#   XRDP sessions. Includes LightDM, LXQt panels, Openbox, configuration tools,
#   power management, notifications, qterminal, and PCManFM-Qt. Excludes heavy
#   Lubuntu applications such as LibreOffice, Discover, Thunderbird, Snap, and
#   multimedia apps. Ensures /etc/skel includes a Desktop directory for new
#   user profiles.
#
# Notes:
#   - Installs only essential LXQt components (Lubuntu "feel" without the bloat).
#   - Snap is removed earlier in the build; no snap-removal steps included here.
#   - Script exits immediately on any error due to 'set -euo pipefail'.
# ==============================================================================

# ==============================================================================
# Step 1: Update package index
# ==============================================================================
apt-get update -y

# ==============================================================================
# Step 2: Install core LXQt desktop components
# ==============================================================================
apt-get install -y \
  lxqt \
  lxqt-core \
  lxqt-config \
  lxqt-panel \
  lxqt-session \
  lxqt-policykit \
  lxqt-sudo \
  lxqt-powermanagement \
  lxqt-runner \
  lxqt-notificationd

# ==============================================================================
# Step 3: Install window manager, terminal, file manager
# ==============================================================================
apt-get install -y \
  openbox \
  obconf-qt \
  pcmanfm-qt \
  qterminal

# ==============================================================================
# Step 4: Install LightDM display manager (thin, XRDP-friendly)
# ==============================================================================
apt-get install -y lightdm lightdm-gtk-greeter

# ==============================================================================
# Step 5: Install clipboard utilities
# ==============================================================================
apt-get install -y xsel xclip copyq

# ==============================================================================
# Step 6: Configure qterminal as the default terminal emulator
# ==============================================================================
update-alternatives --install \
  /usr/bin/x-terminal-emulator \
  x-terminal-emulator \
  /usr/bin/qterminal \
  50

# ==============================================================================
# Step 7: Ensure new users receive a Desktop directory
# ==============================================================================

mkdir -p /etc/skel/Desktop
sudo mkdir -p /etc/xdg/lxqt
sudo tee /etc/xdg/lxqt/session.conf >/dev/null <<'EOF'
[Session]
window_manager=openbox
EOF
sudo mkdir -p /etc/skel/.config/lxqt

sudo tee /etc/skel/.config/lxqt/session.conf >/dev/null <<'EOF'
[Session]
window_manager=openbox
EOF


# ==============================================================================
# Step 8: No wallpaper or theme adjustments required
# ==============================================================================
# LXQt uses its own lightweight theme defaults; no actions required.
# ==============================================================================

sudo apt remove -y gvfs gvfs-backends gvfs-fuse
echo "NOTE: Lubuntu Cloud Edition installation complete."


# ================================================================================
# Step 9: REMOVE NETWORKMANAGER (Critical for Azure Stability)
# ================================================================================
# Lubuntu pulls in NetworkManager. Azure cannot use it reliably — it conflicts
# with cloud-init and prevents NIC initialization after reboot.

sudo apt-get remove --purge -y network-manager
sudo apt-get autoremove -y

# ================================================================================
# Step 10: PREVENT NETWORKMANAGER FROM EVER BEING REINSTALLED
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
