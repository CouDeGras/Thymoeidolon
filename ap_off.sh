#!/usr/bin/env bash
# ap-off.sh ─ Switch Orange Pi from hotspot → client
#   • Stops AP + extra services
#   • Masks dnsmasq so NM can run its own resolver
#   • Returns wlan0 to full NetworkManager control
#   • Safe to re-run (idempotent)

set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "⚠️  Run this script with sudo/root."; exit 1; }

NM_CONF=/etc/NetworkManager/NetworkManager.conf
SERVICES=(hostapd ttyd smbd nmbd filebrowser nginx)

echo "⛔  Stopping hotspot + auxiliary services…"
for svc in "${SERVICES[@]}"; do
  if systemctl list-unit-files | grep -q "^${svc}.*service"; then
    systemctl stop "${svc}.service" || true
  fi
done

echo "🚫  Disabling dnsmasq to free DNS for STA mode…"
systemctl stop    dnsmasq.service || true
systemctl disable dnsmasq.service || true     # prevent auto-start
systemctl mask    dnsmasq.service || true     # ensure no accidental start

echo "📴  Clearing wlan0 state…"
ip addr flush dev wlan0 2>/dev/null || true
ip link set  wlan0 down            2>/dev/null || true

echo "🛠  Restoring NetworkManager control of wlan0…"
# 1) Comment out unmanaged-devices line (if present)
if grep -q '^unmanaged-devices=interface-name:wlan0' "$NM_CONF"; then
  sed -i 's/^unmanaged-devices=interface-name:wlan0/#&/' "$NM_CONF"
fi

# 2) Ensure [ifupdown] managed=true
if grep -q '^\[ifupdown\]' "$NM_CONF"; then
  sed -i '/^\[ifupdown\]/,/^\[/{s/^managed=.*/managed=true/}' "$NM_CONF"
else
  printf '\n[ifupdown]\nmanaged=true\n' >> "$NM_CONF"
fi

# 3) Inform NetworkManager live (best-effort)
nmcli dev set wlan0 managed yes 2>/dev/null || true

echo "🔄  Restarting NetworkManager…"
systemctl restart NetworkManager
sleep 3
nmcli radio wifi on 2>/dev/null || true   # ensure Wi-Fi radio is up

echo "✅  wlan0 is now under NetworkManager control."
echo "    Example:  nmcli device wifi connect \"<HOME_SSID>\" password \"<PASSWORD>\""
