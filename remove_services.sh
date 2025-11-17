#!/bin/bash
echo "==> Searching for siem-* services..."

SERVICES=$(systemctl list-unit-files | awk '/^kuma-/{print $1}')

if [ -z "$SERVICES" ]; then
    echo "No kuma-* services found."
    exit 0
fi

echo "Found:"
echo "$SERVICES"
echo

for S in $SERVICES; do
    echo "==> Stopping $S"
    systemctl stop "$S" 2>/dev/null

    echo "==> Disabling $S"
    systemctl disable "$S" 2>/dev/null

    # Remove unit file
    for P in /etc/systemd/system /usr/lib/systemd/system; do
        if [ -f "$P/$S" ]; then
            echo "==> Removing $P/$S"
            rm "$P/$S"
        fi
    done
done

echo "==> Reloading systemd"
systemctl daemon-reload

echo "Done."
