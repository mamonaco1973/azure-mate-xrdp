#!/bin/bash
set -euo pipefail

# ==========================================================================================
# This script prepares an Ubuntu host for:
#   - Active Directory domain joins using realmd, SSSD, and adcli
#   - NSS/PAM integration for domain users and automatic home directory creation
#   - Samba utilities required for Kerberos, NTLM, and domain discovery
# ==========================================================================================

export DEBIAN_FRONTEND=noninteractive

# Snap stays installed: Firefox is a snap on 26.04, and the XAUTHORITY
# export in /etc/xrdp/startwm.sh (xrdp.sh) lets snaps open windows under XRDP.

systemctl stop unattended-upgrades || true
systemctl stop apt-daily.service apt-daily-upgrade.service || true

apt-get update -y
apt-get upgrade -y
apt-get autoremove -y
apt-get clean

# ------------------------------------------------------------------------------------------
# Install Core AD, NSS, Samba, Kerberos, NFS, and Utility Packages
# ------------------------------------------------------------------------------------------
# Includes:
#   - realmd / adcli / krb5-user     : Domain discovery and Kerberos auth
#   - sssd-ad / libnss-sss / libpam-sss : Identity + authentication via SSSD
#   - samba-common-bin / samba-libs  : Required for domain membership operations
#   - oddjob / oddjob-mkhomedir      : Auto-create home directories for AD users
#   - nfs-common                     : Required for EFS and NFS mounts
#   - stunnel4                       : Enables TLS for amazon-efs-utils
#   - less / unzip / nano / vim      : Basic utilities
# ------------------------------------------------------------------------------------------

apt-get install -y less unzip realmd sssd-ad sssd-tools libnss-sss \
    libpam-sss adcli samba samba-common-bin samba-libs oddjob \
    oddjob-mkhomedir packagekit krb5-user nano vim nfs-common \
    winbind libpam-winbind libnss-winbind stunnel4 jq

# ---------------------------------------------------------------------------------
# Install AZ NFS Helper
# ---------------------------------------------------------------------------------

# Microsoft's 26.04 repository is signed with the 2025 key, not microsoft.asc.
curl -sSL https://packages.microsoft.com/keys/microsoft-2025.asc | sudo gpg --dearmor --yes \
  -o /etc/apt/keyrings/microsoft-2025.gpg

echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft-2025.gpg] \
https://packages.microsoft.com/ubuntu/26.04/prod resolute main" \
  | sudo tee /etc/apt/sources.list.d/aznfs.list

echo "aznfs aznfs/enable_autoupdate boolean true" | sudo debconf-set-selections

apt-get update -y
apt-get install -y aznfs  
