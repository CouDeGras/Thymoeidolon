#!/bin/bash
# Run once (as root). Then: sudo reboot
set -e

# 1️⃣ Parameters
WIFI_IFACE="${1:-wlan0}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORTAL_DIR="$SCRIPT_DIR"

SSID_STA="Oneirodyne"
PSK_STA="Oneirodyne"

SSID_AP="Thymoeidolon"
CHANNEL=6
STATIC_NET="192.168.50.1/24"
STATIC_IP="${STATIC_NET%%/*}"

echo "🔧 Interface:       $WIFI_IFACE"
echo "🌐 Portal dir:     $PORTAL_DIR"
echo "📶 STA SSID:       $SSID_STA"
echo "📡 AP SSID:        $SSID_AP"

# 2️⃣ Install prerequisites
apt update
apt install -y software-properties-common
add-apt-repository -y universe
apt update
apt install -y wpasupplicant hostapd nginx iptables-persistent \
               build-essential libmicrohttpd-dev libssl-dev git

# 3️⃣ Build & install Nodogsplash from source
git clone https://github.com/nodogsplash/nodogsplash.git /tmp/nodogsplash
cd /tmp/nodogsplash
make                                    # build the captive-portal daemon :contentReference[oaicite:0]{index=0}
make install                            # installs /usr/local/sbin/nodogsplash, config → /etc/nodogsplash/ :contentReference[oaicite:1]{index=1}
cd -
rm -rf /tmp/nodogsplash

# 4️⃣ nginx: serve YOUR portal repo
NGINX_CONF=/etc/nginx/sites-available/portal
cat >"$NGINX_CONF" <<EOF
server {
    listen 80;
    server_name _;
    root $PORTAL_DIR;
    index index.html index.htm;
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/portal
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl enable --now nginx          # start & enable the web server

# 5️⃣ nodogsplash config (captive portal)
mkdir -p /etc/nodogsplash
cat >/etc/nodogsplash/nodogsplash.conf <<EOF
GatewayInterface $WIFI_IFACE
MaxClients 50
ClientTimeout 300
RedirectURL http://$STATIC_IP
EOF

# 6️⃣ hostapd: define fallback AP :contentReference[oaicite:2]{index=2}
cat >/etc/hostapd/hostapd.conf <<EOF
interface=$WIFI_IFACE
driver=nl80211
ssid=$SSID_AP
hw_mode=g
channel=$CHANNEL
auth_algs=1
wmm_enabled=0
EOF
sed -i 's|^#DAEMON_CONF.*|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd
systemctl disable hostapd

# 7️⃣ wpa_supplicant: configure STA
WPA_CONF="/etc/wpa_supplicant/wpa_supplicant-$WIFI_IFACE.conf"
cat >"$WPA_CONF" <<EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=US

network={
    ssid="$SSID_STA"
    psk="$PSK_STA"
    key_mgmt=WPA-PSK
}
EOF
systemctl enable wpa_supplicant@"$WIFI_IFACE"

# 8️⃣ Fallback logic script (runs each boot)  
FALLBACK_SCRIPT=/usr/local/bin/wifi_or_ap.sh
cat >"$FALLBACK_SCRIPT" <<EOF
#!/bin/bash
# Run at boot: try STA for 60s, else enable AP+portal

IFACE="$WIFI_IFACE"
STA_SSID="$SSID_STA"
AP_SSID="$SSID_AP"
STATIC_NET="$STATIC_NET"

# Try STA
for i in {1..60}; do
  if iw dev \$IFACE link | grep -q "\$STA_SSID"; then
    echo "✅ Joined \$STA_SSID"
    exit 0
  fi
  sleep 1
done

echo "⚠️  STA failed—starting AP (\$AP_SSID)."

# Stop STA
systemctl stop wpa_supplicant@\$IFACE

# Reset interface
ip link set \$IFACE down
ip addr flush dev \$IFACE
ip link set \$IFACE up

# Assign AP IP
ip addr add \$STATIC_NET dev \$IFACE

# Start AP + captive portal
systemctl start hostapd
systemctl start nodogsplash
EOF
chmod +x "$FALLBACK_SCRIPT"

# 9️⃣ systemd unit for fallback logic :contentReference[oaicite:3]{index=3}
FALLBACK_SERVICE=/etc/systemd/system/fallback-ap.service
cat >"$FALLBACK_SERVICE" <<EOF
[Unit]
Description=Fallback to AP if STA fails
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=$FALLBACK_SCRIPT

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd to pick up new unit
systemctl daemon-reload
systemctl enable fallback-ap.service

# 🔟 IPTABLES: redirect HTTP → portal :contentReference[oaicite:4]{index=4}
iptables -t nat -A PREROUTING -i "$WIFI_IFACE" -p tcp --dport 80 \
        -j DNAT --to-destination $STATIC_IP:80
iptables -t nat -A POSTROUTING -j MASQUERADE
netfilter-persistent save

echo -e "\n✅ Installation complete. Reboot to apply:"
echo "   sudo reboot"
