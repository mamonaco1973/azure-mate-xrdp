#!/bin/bash
set -euo pipefail

# ==========================================================================================
# This script prepares an Ubuntu host for:
#   - Active Directory domain joins using realmd, SSSD, and adcli
#   - NSS/PAM integration for domain users and automatic home directory creation
#   - Samba utilities required for Kerberos, NTLM, and domain discovery
# ==========================================================================================

# ------------------------------------------------------------------------------------------
# XRDP has issues with snap so disable and remove it first
# ------------------------------------------------------------------------------------------

export DEBIAN_FRONTEND=noninteractive
sudo snap remove --purge core22
sudo snap remove --purge snapd
sudo apt-get purge -y snapd
echo -e "Package: snapd\nPin: release *\nPin-Priority: -10" \
 | sudo tee /etc/apt/preferences.d/nosnap.pref
sudo apt-get update -y

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

curl -sSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor --yes \
  -o /etc/apt/keyrings/microsoft.gpg

echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] \
https://packages.microsoft.com/ubuntu/22.04/prod jammy main" \
  | sudo tee /etc/apt/sources.list.d/aznfs.list

echo "aznfs aznfs/enable_autoupdate boolean true" | sudo debconf-set-selections

apt-get update -y
apt-get install -y aznfs  
