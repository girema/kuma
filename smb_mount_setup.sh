#!/usr/bin/env bash
# exchange_mount_setup.sh — Mount Exchange logs over Kerberos-authenticated SMB
# This script:
#  1. Installs required packages (krb5, cifs-utils)
#  2. Copies the keytab into /etc/security/keytabs
#  3. Configures a systemd timer to renew the Kerberos ticket (kinit)
#  4. Mounts the Exchange logs read-only via CIFS (sec=krb5)
#  5. Verifies mount status and ticket renewal

set -euo pipefail
IFS=$'\n\t'

echo "=== Exchange MessageTracking mount setup (Kerberos-secured CIFS) ==="

if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root or with sudo." >&2
  exit 1
fi

read -p "UNC path to Exchange share (e.g. //EXCHANGE01/exchlogs): " REMOTE_SHARE
read -p "Local mount point (e.g. /mnt/exchange_logs): " LOCAL_MOUNT
read -p "Kerberos principal (e.g. siem_user@EXAMPLE.LOCAL): " KRB_PRINCIPAL
read -p "Path to keytab on this host (e.g. /root/siem_user.keytab): " KEYTAB_SRC
read -p "Add fstab entry for automatic mounting? (y/N): " USE_FSTAB

KEYTAB_DEST="/etc/security/keytabs/$(basename $KEYTAB_SRC)"
KINIT_UNIT="/etc/systemd/system/kinit-siem.service"
KINIT_TIMER="/etc/systemd/system/kinit-siem.timer"

echo "Installing required packages..."
if command -v apt >/dev/null 2>&1; then
  apt update && DEBIAN_FRONTEND=noninteractive apt install -y krb5-user cifs-utils || true
elif command -v yum >/dev/null 2>&1; then
  yum install -y krb5-workstation cifs-utils || true
fi

if [ ! -f "$KEYTAB_SRC" ]; then
  echo "Keytab not found: $KEYTAB_SRC" >&2
  exit 1
fi

mkdir -p /etc/security/keytabs
cp "$KEYTAB_SRC" "$KEYTAB_DEST"
chmod 600 "$KEYTAB_DEST"

mkdir -p "$LOCAL_MOUNT"

# systemd service and timer for Kerberos ticket renewal
cat > "$KINIT_UNIT" <<KINIT
[Unit]
Description=Renew Kerberos ticket for ${KRB_PRINCIPAL}
[Service]
Type=oneshot
ExecStart=/usr/bin/kinit -k -t ${KEYTAB_DEST} ${KRB_PRINCIPAL}
KINIT

cat > "$KINIT_TIMER" <<KTIMER
[Unit]
Description=Renew Kerberos ticket for ${KRB_PRINCIPAL} every 8h
[Timer]
OnBootSec=1min
OnUnitActiveSec=8h
Persistent=true
[Install]
WantedBy=timers.target
KTIMER

systemctl daemon-reload
systemctl enable --now kinit-siem.timer || true

if [[ "$USE_FSTAB" =~ ^[Yy] ]]; then
  ESC_REMOTE=$(echo "$REMOTE_SHARE" | sed 's/ /\\040/g')
  echo "${ESC_REMOTE} ${LOCAL_MOUNT} cifs sec=krb5,vers=3.0,ro,_netdev 0 0" >> /etc/fstab
  mount -a || true
fi

/usr/bin/kinit -k -t "$KEYTAB_DEST" "$KRB_PRINCIPAL" || true
mount -t cifs "$REMOTE_SHARE" "$LOCAL_MOUNT" -o sec=krb5,vers=3.0,ro,_netdev || true

echo
if mountpoint -q "$LOCAL_MOUNT"; then
  echo "✅ Successfully mounted: $LOCAL_MOUNT"
else
  echo "❌ Mount failed. Please check Kerberos or folder permissions." >&2
fi

sleep 2
systemctl is-active --quiet kinit-siem.timer && echo "✅ kinit timer active" || echo "❌ kinit timer inactive"

if [ -n "$(ls -A $LOCAL_MOUNT 2>/dev/null || true)" ]; then
  echo "✅ Files found in $LOCAL_MOUNT:"
  ls -1 "$LOCAL_MOUNT" | head -n 5
else
  echo "⚠️ Folder appears empty or access denied. Check Exchange permissions." >&2
fi

echo
cat <<EOF
Setup completed successfully.
Keytab: $KEYTAB_DEST
Mount point: $LOCAL_MOUNT
Kerberos timer: kinit-siem.timer (refreshes every 8h)

Check mount status: mount | grep "$LOCAL_MOUNT"
View kinit logs: journalctl -u kinit-siem.service -b
EOF

exit 0
