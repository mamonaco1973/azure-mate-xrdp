#!/bin/bash
set -euo pipefail

# ================================================================================
# Desktop Icon Provisioning Script (System-Wide Defaults)
# ================================================================================
# Description:
#   Creates trusted symlinks for selected applications inside /etc/skel/Desktop.
#   These symlinks ensure that all newly created users receive desktop icons
#   without the XFCE/LXQT "untrusted application launcher" warning dialog.
#
# Notes:
#   - Works for XFCE, MATE, LXQT and most desktop environments using .desktop files.
#   - Only affects *new* users created after this script runs.
#   - Symlinks are used instead of copied launchers to preserve trust flags.
# ================================================================================

# ================================================================================
# Configuration: Applications to appear on every new user's desktop
# ================================================================================
APPS=(
  /usr/share/applications/google-chrome.desktop
  /usr/share/applications/firefox.desktop
  /usr/share/applications/code.desktop
  /usr/share/applications/postman.desktop
  /usr/share/applications/onlyoffice-desktopeditors.desktop
)

SKEL_DESKTOP="/etc/skel/Desktop"

# ================================================================================
# Step 1: Ensure the skeleton Desktop directory exists
# ================================================================================
echo "NOTE: Ensuring /etc/skel/Desktop exists..."
mkdir -p "$SKEL_DESKTOP"

# ================================================================================
# Step 2: Create trusted symlinks for all selected applications
# ================================================================================
echo "NOTE: Creating trusted symlinks in /etc/skel/Desktop..."

for src in "${APPS[@]}"; do
  if [[ -f "$src" ]]; then
    filename=$(basename "$src")
    ln -sf "$src" "$SKEL_DESKTOP/$filename"
    echo "NOTE: Added $filename (trusted symlink)"
  else
    echo "WARNING: $src not found, skipping"
  fi
done

echo "NOTE: All new users will receive these desktop icons without trust prompts."

# ================================================================================
# Step 3: Lubuntu configurations for XRDP
# ================================================================================

sudo mkdir -p /etc/xdg/lxqt

# Specify default applications and window manager

sudo tee /etc/xdg/lxqt/session.conf >/dev/null <<'EOF'
[Environment]
BROWSER=firefox
TERM=qterminal
[General]
window_manager=openbox
EOF

# Configure LXQt panel with essential plugins and quicklaunchers
# Turned off problematic plugins for XRDP sessions

sudo tee /etc/xdg/lxqt/panel.conf >/dev/null <<'EOF'
[General]
iconTheme=Papirus-Dark

[kbindicator]
alignment=Right
type=kbindicator

[quicklaunch]
alignment=Left
apps\1\desktop=/usr/share/applications/pcmanfm-qt.desktop
apps\2\desktop=/usr/share/applications/qterminal.desktop
apps\3\desktop=/usr/share/applications/featherpad.desktop
apps\size=3
type=quicklaunch

[quicklaunch2]
alignment=left
apps\1\desktop=/usr/share/applications/lxqt-leave.desktop
apps\size=1
type=quicklaunch

[panel1]
plugins=mainmenu, showdesktop, desktopswitch, quicklaunch, taskbar, tray, statusnotifier, worldclock, quicklaunch2

[taskbar]
buttonWidth=200
raiseOnCurrentDesktop=true
EOF

# Configure PCManFM-Qt to show Desktop shortcuts and set default wallpaper

sudo tee /etc/xdg/pcmanfm-qt/lxqt/settings.conf >/dev/null <<'EOF'
[Desktop]
DesktopShortcuts=Home
Wallpaper=/usr/share/lxqt/themes/debian/wallpaper.svg
WallpaperMode=zoom
WallpaperRandomize=false

[System]
Archiver=xarchiver
FallbackIconThemeName=oxygen
Terminal=qterminal

[Window]
AlwaysShowTabs=true

[Behavior]
QuickExec=true
EOF

# Remove powermanagement to prevent conflicts with XRDP sessions

sudo apt-get purge -y lxqt-powermanagement
sudo apt-get autoremove -y
