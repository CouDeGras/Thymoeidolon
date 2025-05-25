#!/bin/bash
# install_wifi_or_ap_portal.sh
# Run this ONCE (with sudo).  Afterwards, reboot: 
#   sudo ./install_wifi_or_ap_portal.sh wlan0
#   sudo reboot
# The fallback-ap.service will then run automatically on each boot.

set -e

WIFI_IFACE="${1:-wlan0}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORTAL_DIR="$SCRIPT_DIR"

# STA credentials
SSID_STA="Oneirodyne"
PSK_STA="Oneirodyne"

# AP settings
SSID_AP="Thymoeidolon"
CHANNEL=6
STATIC_NET="192.168.50.1/24"
STATIC_IP="${STATIC_NET%%/*}"

echo "🔧 Install running for interface: $WIFI_IFACE"
echo "🌐 Captive portal rooted at: $PORTAL_DIR"
echo "📶 STA target SSID:     $SSID_STA"
echo "📡 AP SSID (fallback):  $SSID_AP"

# 1. Install packages
# 1. Install the helper to add repos
sudo apt update
sudo apt install -y software-properties-common

# 2. Enable Universe
sudo add-apt-repository universe

# 3. Refresh and install the correct packages
sudo apt update
sudo apt install -y wpasupplicant hostapd nginx iptables-persistent
 
sudo apt install -y build-essential libmicrohttpd-dev libssl-dev git  
git clone https://github.com/nodogsplash/nodogsplash.git
cd nodogsplash
make
sudo make install
which nodogsplash       # should return /usr/local/sbin/nodogsplash
nodogsplash -v          # prints version (e.g., 3.3.3-beta)


# 2. Nginx config → serve YOUR portal repo
NGINX_CONF=/etc/nginx/sites-available/portal
tee "$NGINX_CONF" > /dev/null <<EOF
server {
    listen 80;
    server_name _;
    root $PORTAL_DIR;
    index index.html index.htm;
    location / { try_files \$uri \$uri/ =404; }
}
EOF
ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/portal
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl enable nginx
systemctl restart nginx

# 3. nodogsplash config (but don’t start it now)
tee /etc/nodogsplash/nodogsplash.conf > /dev/null <<EOF
GatewayInterface $WIFI_IFACE
MaxClients 50
ClientTimeout 300
RedirectURL http://$STATIC_IP
EOF

# 4. hostapd config (AP)
tee /etc/hostapd/hostapd.conf > /dev/null <<EOF
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

# 5. wpa_supplicant config (STA)
WPA_CONF="/etc/wpa_supplicant/wpa_supplicant-${WIFI_IFACE}.conf"
tee "$WPA_CONF" > /dev/null <<EOF
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

# 6. Fallback script (runs on every boot via systemd)
FALLBACK_SCRIPT=/usr/local/bin/wifi_or_ap.sh
tee "$FALLBACK_SCRIPT" > /dev/null <<'EOF'
#!/bin/bash
# wifi_or_ap.sh — tries STA for 60 s, else sets up AP+captive portal

IFACE="'"$WIFI_IFACE"'"
STA_SSID="'"$SSID_STA"'"
AP_SSID="'"$SSID_AP"'"
STATIC_NET="'"$STATIC_NET"'"
STATIC_IP="${STATIC_NET%%/*}"

# 1. Try to join STA
for i in {1..60}; do
    if iw dev $IFACE link | grep -q "$STA_SSID"; then
        echo "✅ Joined $STA_SSID"
        exit 0
    fi
    sleep 1
done

echo "⚠️  STA failed. Falling back to AP ($AP_SSID)."

# 2. Stop STA
systemctl stop wpa_supplicant@$IFACE

# 3. Reset interface
ip link set $IFACE down
ip addr flush dev $IFACE
ip link set $IFACE up

# 4. Assign AP static IP
ip addr add $STATIC_NET dev $IFACE

# 5. Start AP and Captive Portal
systemctl start hostapd
systemctl start nodogsplash
EOF
chmod +x "$FALLBACK_SCRIPT"

# 7. Create & enable systemd unit
FALLBACK_SERVICE=/etc/systemd/system/fallback-ap.service
tee "$FALLBACK_SERVICE" > /dev/null <<EOF
[Unit]
Description=Fallback to AP mode if STA fails
After=network.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$FALLBACK_SCRIPT
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF
systemctl enable fallback-ap.service

# 8. IPTABLES HTTP redirect
iptables -t nat -A PREROUTING -i "$WIFI_IFACE" -p tcp --dport 80 \
    -j DNAT --to-destination $STATIC_IP:80
iptables -t nat -A POSTROUTING -j MASQUERADE
netfilter-persistent save

echo -e "\n✅ One-time install complete. Please reboot now:"
echo "   sudo reboot"
