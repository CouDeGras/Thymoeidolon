#!/usr/bin/env bash
# ap-up.sh ─ Toggle Orange Pi into HOTSPOT mode
#  * Disables NetworkManager control of wlan0
#  * Brings up hostapd + dnsmasq + custom services
#  * Idempotent: safe to re-run

set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "⚠️  Run this script with sudo/root"; exit 1; }

AP_IP="192.168.4.1/24"
NM_CONF="/etc/NetworkManager/NetworkManager.conf"
SLEEP=4            # seconds to wait for Unisoc driver after hostapd

echo "⛔  Removing wlan0 from NetworkManager control…"

# Ensure unmanaged-devices entry exists exactly once
if ! grep -q 'unmanaged-devices=interface-name:wlan0' "$NM_CONF"; then
  sed -i '/^\[keyfile\]/!b;:a;n;/^\[/b; ba' "$NM_CONF" 2>/dev/null || true
  echo -e '\n[keyfile]\nunmanaged-devices=interface-name:wlan0' >>"$NM_CONF"
fi
nmcli dev set wlan0 managed no 2>/dev/null || true
systemctl restart NetworkManager
sleep 2

echo "🔄 Resetting wlan0…"
ip addr flush dev wlan0 2>/dev/null || true
ip link set  wlan0 down            2>/dev/null || true

echo "🚀 Starting hostapd…"
systemctl restart hostapd
sleep "$SLEEP"

echo "📡 Assigning static IP $AP_IP"
ip addr add "$AP_IP" dev wlan0 2>/dev/null || true

echo "📜 Restarting dnsmasq…"
systemctl restart dnsmasq

# ───── Custom service array (restart ensures fresh state) ─────
SERVICES=(ttyd smbd nmbd filebrowser nginx)

echo "🔄 Restarting extra services…"
for svc in "${SERVICES[@]}"; do
  if systemctl list-unit-files | grep -q "^${svc}.*service"; then
    echo "▶️  $svc"
    systemctl restart "$svc"
  fi
done

echo "✅ Hotspot ready → http://192.168.4.1"
