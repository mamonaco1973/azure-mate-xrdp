#!/bin/bash
set -euo pipefail

# ================================================================================
# XRDP Installation and MATE Session Configuration Script
# ================================================================================
# Description:
#   Installs XRDP and replaces the default /etc/xrdp/startwm.sh script so that
#   all XRDP logins launch MATE without the untrusted launcher dialog or the
#   default Ubuntu session. The script also ensures the file has correct
#   permissions and enables the XRDP service at boot.
#
# Notes:
#   - Uses apt-get for predictable automation behavior.
#   - Writes a clean startwm.sh that invokes mate-session.
#   - Script exits on any error due to 'set -euo pipefail'.
# ================================================================================

# ================================================================================
# Step 1: Install XRDP
# ================================================================================
sudo apt-get update -y
sudo apt-get install -y xrdp xorgxrdp

# XRDP reads the private key of its TLS certificate (the snakeoil pair).
sudo adduser xrdp ssl-cert

# ================================================================================
# Step 2: Replace /etc/xrdp/startwm.sh with MATE session launcher
# ================================================================================
sudo tee /etc/xrdp/startwm.sh >/dev/null <<'EOF'
#!/bin/sh
# xrdp X session start script (c) 2015, 2017, 2021 mirabilos
# published under The MirOS Licence
#
# Rely on /etc/pam.d/xrdp-sesman using pam_env to load both
# /etc/environment and /etc/default/locale to initialise the
# locale and the user environment properly.

if test -r /etc/profile; then
    . /etc/profile
fi

if test -r ~/.profile; then
    . ~/.profile
fi

# XRDP starts Xorg with "-auth .Xauthority" but does not export XAUTHORITY.
# Ordinary apps find ~/.Xauthority by default; snaps run with a redirected
# $HOME and do not, so X refuses them ("Authorization required").
# An absolute XAUTHORITY lets snapd hand the cookie to the snap.
export XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"

# Start MATE session
exec mate-session

EOF

# ================================================================================
# Step 3: Correct permissions on startwm.sh
# ================================================================================
sudo chmod 755 /etc/xrdp/startwm.sh
echo "NOTE: /etc/xrdp/startwm.sh replaced and permissions set."

# ================================================================================
# Step 4: Enable XRDP service
# ================================================================================
sudo sed -i 's/^max_bpp=32/max_bpp=16/' /etc/xrdp/xrdp.ini
sudo systemctl enable xrdp
echo "NOTE: XRDP installation and configuration complete."

# ---------------------------------------------------------------------------------
# PAM: environment, then the system stack (SSSD + mkhomedir)
# ---------------------------------------------------------------------------------
# Home directories come from pam_mkhomedir in common-session, enabled at boot
# by userdata.sh (pam-auth-update --enable mkhomedir; HOME_MODE 0700).

cat >/etc/pam.d/xrdp-sesman <<'EOF'
#%PAM-1.0
auth required pam_env.so readenv=1
auth required pam_env.so readenv=1 envfile=/etc/default/locale
@include common-auth
@include common-account
@include common-session
@include common-password
EOF

echo "NOTE: Created /etc/pam.d/xrdp-sesman successfully."

# ---------------------------------------------------------------------------------
# Quiet polkit prompts in remote sessions
# ---------------------------------------------------------------------------------
# Remote sessions otherwise get polkit prompts for colour management and
# package refreshes ("Authentication is required to create a color profile").

mkdir -p /etc/polkit-1/rules.d
cat >/etc/polkit-1/rules.d/45-xrdp-quiet.rules <<'EOF'
polkit.addRule(function(action, subject) {
  if (action.id.indexOf("org.freedesktop.color-manager.") === 0 ||
      action.id === "org.freedesktop.packagekit.system-sources-refresh") {
    return polkit.Result.YES;
  }
});
EOF

echo "NOTE: Polkit rule for XRDP sessions installed."
