#!/bin/bash

# This script automates the process of updating the OS, installing required packages,
# joining an Active Directory (AD) domain, configuring system settings, and cleaning
# up permissions.

# ---------------------------------------------------------------------------------
# Section 1: Mount NFS file system
# ---------------------------------------------------------------------------------

mkdir -p /nfs
mkdir -p /nfs/home

cat <<EOF | sudo tee -a /etc/fstab > /dev/null
${storage_account}.file.core.windows.net:/${storage_account}/nfs      /nfs        aznfs defaults,vers=4.1,sec=sys,nolock,proto=tcp,_netdev,nofail,bg 0 0
EOF

systemctl daemon-reload

# Try mounts now

mount /nfs || true
mkdir -p /nfs/home
mkdir -p /nfs/data
mv /home /home.local
ln -s /nfs/home /home

# ---------------------------------------------------------------------------------
# Section 2: Configure AD as the identity provider
# ---------------------------------------------------------------------------------

az login --identity --allow-no-subscriptions
secretsJson=$(az keyvault secret show --name admin-credentials --vault-name ${vault_name} --query value -o tsv)
admin_password=$(echo "$secretsJson" | jq -r '.password')
admin_username="${netbios}\\Admin"

# Perform AD join with Samba as membership software (logs to /root/join.log)
echo -e "$admin_password" | sudo /usr/sbin/realm join --membership-software=samba \
    -U "$admin_username" ${domain_fqdn} --verbose >> /root/join.log 2>&1

# ---------------------------------------------------------------------------------
# Section 3: Configure SSSD for AD Integration
# ---------------------------------------------------------------------------------

# Modify the SSSD configuration file to simplify user login and home directory creation.
# - Disable fully qualified names (use only usernames instead of user@domain).
sudo sed -i 's/use_fully_qualified_names = True/use_fully_qualified_names = False/g' \
    /etc/sssd/sssd.conf

# Disable LDAP ID mapping to use UIDs and GIDs from AD.
sudo sed -i 's/ldap_id_mapping = True/ldap_id_mapping = False/g' \
    /etc/sssd/sssd.conf

# Change the fallback home directory path to a simpler format (/home/%u).
sudo sed -i 's|fallback_homedir = /home/%u@%d|fallback_homedir = /home/%u|' \
    /etc/sssd/sssd.conf

# Update access provider to 'simple' to allow all authenticated users.
sudo sed -i \
  -e 's/^access_provider *= *.*/access_provider = simple/' \
  /etc/sssd/sssd.conf

# Stop XAuthority warning 

touch /etc/skel/.Xauthority
chmod 600 /etc/skel/.Xauthority

# Restart the SSSD and SSH services to apply the changes.

sudo pam-auth-update --enable mkhomedir
sudo systemctl restart sssd
sudo systemctl restart ssh

# ---------------------------------------------------------------------------------
# Section 7: Configure Samba File Server
# ---------------------------------------------------------------------------------
# Stop SSSD temporarily to allow Samba configuration updates
sudo systemctl stop sssd

# Write Samba configuration file (smb.conf) with AD + Winbind integration
cat <<EOT > /tmp/smb.conf
[global]
workgroup = ${netbios}
security = ads

# Performance tuning
strict sync = no
sync always = no
aio read size = 1
aio write size = 1
use sendfile = yes

passdb backend = tdbsam

# Printing subsystem (legacy, usually unused in cloud)
printing = cups
printcap name = cups
load printers = yes
cups options = raw

kerberos method = secrets and keytab

# Default user template
template homedir = /home/%U
template shell = /bin/bash
#netbios 

# File creation masks
create mask = 0770
force create mode = 0770
directory mask = 0770
force group = ${force_group}

realm = ${realm}

# ID mapping configuration
idmap config ${realm} : backend = sss
idmap config ${realm} : range = 10000-1999999999
idmap config * : backend = tdb
idmap config * : range = 1-9999

# Winbind options
min domain uid = 0
winbind use default domain = yes
winbind normalize names = yes
winbind refresh tickets = yes
winbind offline logon = yes
winbind enum groups = yes
winbind enum users = yes
winbind cache time = 30
idmap cache time = 60

[homes]
comment = Home Directories
browseable = No
read only = No
inherit acls = Yes

[nfs]
comment = Mounted EFS area
path = /nfs
read only = no
guest ok = no
EOT

# Deploy Samba configuration
sudo cp /tmp/smb.conf /etc/samba/smb.conf
sudo rm /tmp/smb.conf

# Insert NetBIOS hostname dynamically
head /etc/hostname -c 15 > /tmp/netbios-name
value=$(</tmp/netbios-name)
export netbios="$${value^^}"
sudo sed -i "s/#netbios/netbios name=$netbios/g" /etc/samba/smb.conf

# Update NSSwitch configuration for Winbind integration
cat <<EOT > /tmp/nsswitch.conf
passwd:     files sss winbind
group:      files sss winbind
automount:  files sss winbind
shadow:     files sss winbind
hosts:      files dns myhostname
bootparams: nisplus [NOTFOUND=return] files
ethers:     files
netmasks:   files
networks:   files
protocols:  files
rpc:        files
services:   files sss
netgroup:   files sss
publickey:  nisplus
aliases:    files nisplus
EOT

sudo cp /tmp/nsswitch.conf /etc/nsswitch.conf
sudo rm /tmp/nsswitch.conf

# Restart Samba-related services
sudo systemctl restart winbind smb nmb sssd

# ---------------------------------------------------------------------------------
# Section 4: Grant Sudo Privileges to AD Linux Admins
# ---------------------------------------------------------------------------------

# Add a sudoers rule to grant passwordless sudo access to members of the
# "linux-admins" AD group.
sudo echo "%linux-admins ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/10-linux-admins

# ---------------------------------------------------------------------------------
# Section 5: Enforce Home Directory Permissions
# ---------------------------------------------------------------------------------
# Force new home directories to have mode 0700 (private)
sudo sed -i 's/^\(\s*HOME_MODE\s*\)[0-9]\+/\10700/' /etc/login.defs

# Trigger home directory creation for specific test accounts

su -c "exit" rpatel
su -c "exit" jsmith
su -c "exit" akumar
su -c "exit" edavis

# Set NFS directory ownership and permissions
chgrp mcloud-users /nfs
chgrp mcloud-users /nfs/data
chmod 775 /nfs
chmod 775 /nfs/data
chmod 700 /home/*

cd /nfs
git clone https://github.com/mamonaco1973/azure-xubuntu-xrdp.git
chmod -R 775 azure-xubuntu-xrdp
chgrp -R mcloud-users azure-xubuntu-xrdp

git clone https://github.com/mamonaco1973/azure-lubuntu-xrdp.git
chmod -R 775 azure-lubuntu-xrdp
chgrp -R mcloud-users azure-lubuntu-xrdp

git clone https://github.com/mamonaco1973/azure-mate-xrdp.git
chmod -R 775 azure-mate-xrdp
chgrp -R mcloud-users azure-mate-xrdp

git clone https://github.com/mamonaco1973/aws-setup.git
chmod -R 775 aws-setup
chgrp -R mcloud-users aws-setup

git clone https://github.com/mamonaco1973/azure-setup.git
chmod -R 775 azure-setup
chgrp -R mcloud-users azure-setup

git clone https://github.com/mamonaco1973/gcp-setup.git
chmod -R 775 gcp-setup
chgrp -R mcloud-users gcp-setup
