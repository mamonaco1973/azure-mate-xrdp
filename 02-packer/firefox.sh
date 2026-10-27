#!/bin/bash
set -euo pipefail

# ================================================================================
# Firefox Installation Script (Snap)
# ================================================================================
# Description:
#   Installs Firefox from the Snap Store, Ubuntu's default packaging. Snaps
#   need the XAUTHORITY export in /etc/xrdp/startwm.sh (xrdp.sh) to open
#   windows in an XRDP session.
# ================================================================================

# Wait for snapd's first-boot seeding before installing.
snap wait system seed.loaded
snap install firefox

# A snap registers no Debian alternatives, so x-www-browser and www-browser
# find nothing. Register Firefox for both names.
#
# Through a wrapper, not a symlink: /snap/bin/firefox is itself a symlink to
# /usr/bin/snap, which picks the app from the name it is invoked by -- run
# as "www-browser" it does not know it means Firefox.
cat > /usr/local/bin/firefox-snap <<'WRAPPER'
#!/bin/sh
exec /snap/bin/firefox "$@"
WRAPPER
chmod 755 /usr/local/bin/firefox-snap
for name in x-www-browser www-browser; do
  update-alternatives --install "/usr/bin/$name" "$name" /usr/local/bin/firefox-snap 200
done

echo "NOTE: Firefox installed from the Snap Store."
