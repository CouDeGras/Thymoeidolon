#!/usr/bin/env bash
# ap-off.sh ─ Return wlan0 to NetworkManager client mode
# * Stops hotspot & auxiliary services
# * Re-enables NM control of wlan0 (undoes unmanaged rule)
# * Safe to re-run (idempotent)

set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "⚠️  Run this script with sudo/root"; exit 1; }

NMFILE=/etc/NetworkManager/NetworkManager.conf
SERVICES=(ttyd smbd nmbd filebrowser nginx dnsmasq hostapd)

echo "⛔  Stopping hotspot + extra services…"
for svc in "${SERVICES[@]}"; do
  if systemctl list-unit-files | grep -q "^${svc}.*service"; then
    systemctl stop "$svc" || true
  fi
done

echo "📴  Flushing wlan0 & bringing it down…"
ip addr flush dev wlan0 2>/dev/null || true
ip link set  wlan0 down            2>/dev/null || true

echo "🔄  Returning wlan0 to NetworkManager control…"
# Comment the unmanaged line (only if it’s active, not already commented)
if grep -q '^unmanaged-devices=interface-name:wlan0' "$NMFILE"; then
  sed -i 's/^unmanaged-devices=interface-name:wlan0/#&/' "$NMFILE"
fi

# Tell a modern NM instantly; older versions ignore but restart covers it
nmcli dev set wlan0 managed yes 2>/dev/null || true

systemctl restart NetworkManager
sleep 3
nmcli radio wifi on 2>/dev/null || true

echo "✅  wlan0 is now managed by NetworkManager."
echo "    Example to connect:"
echo "      nmcli device wifi connect \"<HOME_SSID>\" password \"<PASSWORD>\""
