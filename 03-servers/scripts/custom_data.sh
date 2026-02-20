#!/bin/bash

set -euo pipefail

# Logging
LOG=/root/boot.log
mkdir -p /root
touch "$LOG"
chmod 600 "$LOG"
exec > >(tee -a "$LOG" | logger -t user-data -s 2>/dev/console) 2>&1
trap 'echo "ERROR at line $LINENO"; exit 1' ERR
echo "user-data start: $(date -Is)"

# NFS setup
mkdir -p /nfs

cat <<EOF | sudo tee -a /etc/fstab > /dev/null
${storage_account}.file.core.windows.net:/${storage_account}/nfs      /nfs        aznfs defaults,vers=4.1,sec=sys,nolock,proto=tcp,_netdev,nofail,bg 0 0
EOF

systemctl daemon-reload
mount /nfs || true
mkdir -p /nfs/home
mkdir -p /nfs/data
mv /home /home.local
ln -s /nfs/home /home

# AD join
az login --identity --allow-no-subscriptions
secretsJson=$(az keyvault secret show --name admin-credentials --vault-name ${vault_name} --query value -o tsv)
admin_password=$(echo "$secretsJson" | jq -r '.password')
admin_username="${netbios}\\Admin"

echo -e "$admin_password" | sudo /usr/sbin/realm join --membership-software=samba \
    -U "$admin_username" ${domain_fqdn} --verbose >> /root/join.log 2>&1

# SSSD config
sudo sed -i 's/use_fully_qualified_names = True/use_fully_qualified_names = False/g' \
    /etc/sssd/sssd.conf

sudo sed -i 's/ldap_id_mapping = True/ldap_id_mapping = False/g' \
    /etc/sssd/sssd.conf

sudo sed -i 's|fallback_homedir = /home/%u@%d|fallback_homedir = /home/%u|' \
    /etc/sssd/sssd.conf

sudo sed -i \
  -e 's/^access_provider *= *.*/access_provider = simple/' \
  /etc/sssd/sssd.conf

touch /etc/skel/.Xauthority
chmod 600 /etc/skel/.Xauthority

sudo pam-auth-update --enable mkhomedir
sudo systemctl restart sssd
sudo systemctl restart ssh

# Samba config
sudo systemctl stop sssd

cat <<EOT > /tmp/smb.conf
[global]
workgroup = ${netbios}
security = ads
strict sync = no
sync always = no
aio read size = 1
aio write size = 1
use sendfile = yes
passdb backend = tdbsam
printing = cups
printcap name = cups
load printers = yes
cups options = raw
kerberos method = secrets and keytab
template homedir = /home/%U
template shell = /bin/bash
#netbios
create mask = 0770
force create mode = 0770
directory mask = 0770
force group = ${force_group}
realm = ${realm}
idmap config ${realm} : backend = sss
idmap config ${realm} : range = 10000-1999999999
idmap config * : backend = tdb
idmap config * : range = 1-9999
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

sudo cp /tmp/smb.conf /etc/samba/smb.conf
sudo rm /tmp/smb.conf

head /etc/hostname -c 15 > /tmp/netbios-name
value=$(</tmp/netbios-name)
export netbios="$${value^^}"
sudo sed -i "s/#netbios/netbios name=$netbios/g" /etc/samba/smb.conf

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

sudo systemctl restart winbind smb nmb sssd

# Sudo access
sudo echo "%linux-admins ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/10-linux-admins

# Home perms
sudo sed -i 's/^\(\s*HOME_MODE\s*\)[0-9]\+/\10700/' /etc/login.defs

su -c "exit" rpatel
su -c "exit" jsmith
su -c "exit" akumar
su -c "exit" edavis

chgrp mcloud-users /nfs
chgrp mcloud-users /nfs/data
chmod 775 /nfs
chmod 775 /nfs/data
chmod 700 /home/*

cd /nfs
git clone https://github.com/mamonaco1973/azure-xubuntu-xrdp.git || true
chmod -R 775 azure-xubuntu-xrdp || true
chgrp -R mcloud-users azure-xubuntu-xrdp || true

git clone https://github.com/mamonaco1973/azure-lubuntu-xrdp.git || true
chmod -R 775 azure-lubuntu-xrdp || true
chgrp -R mcloud-users azure-lubuntu-xrdp || true

git clone https://github.com/mamonaco1973/azure-mate-xrdp.git || true
chmod -R 775 azure-mate-xrdp || true
chgrp -R mcloud-users azure-mate-xrdp || true

git clone https://github.com/mamonaco1973/aws-setup.git || true
chmod -R 775 aws-setup || true
chgrp -R mcloud-users aws-setup || true

git clone https://github.com/mamonaco1973/azure-setup.git || true
chmod -R 775 azure-setup || true
chgrp -R mcloud-users azure-setup || true

git clone https://github.com/mamonaco1973/gcp-setup.git || true
chmod -R 775 gcp-setup || true
chgrp -R mcloud-users gcp-setup || true