#!/usr/bin/env bash
#
# Fully-idempotent media-server bootstrapper
#   – ttyd (snap)
#   – File Browser
#   – NGINX from official repo
#   – Samba shares for $HOME and DCIM
#
# Run as root on Ubuntu.

set -Eeuo pipefail
trap 'echo "❌ Error on line $LINENO – exiting."; exit 1' ERR

# ───────────────────────────────────
# 0) pre-flight checks
# ───────────────────────────────────
[[ $EUID -eq 0 ]] || { echo "⚠️  please run with sudo."; exit 1; }
grep -q "Ubuntu" /etc/os-release ||
  { echo "⚠️  Ubuntu-only script (needs snap)"; exit 1; }

# Ensure /snap/bin is discoverable for command -v
export PATH="$PATH:/snap/bin"

# ───────────────────────────────────
# 1) resolve real non-root user + paths
# ───────────────────────────────────
USER_NAME=${SUDO_USER:-$USER}
USER_HOME=$(getent passwd "$USER_NAME" | cut -d: -f6)
BASE_DIR="$USER_HOME/DCIM"

# create DCIM structure (idempotent)
for sub in original processed meta; do
  dir="$BASE_DIR/$sub"
  [[ -d $dir ]] && echo "⚠️  Already exists: $dir" || {
    mkdir -p "$dir"
    echo "✅ Created: $dir"
  }
done
echo "📁 DCIM folder ready at $BASE_DIR"

# ───────────────────────────────────
# 2) helper wrappers
# ───────────────────────────────────
need_cmd()  { command -v "$1" &>/dev/null; }
need_snap() { snap list "$1" &>/dev/null; }
apt_install(){ DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@"; }

# ───────────────────────────────────
# 3) installers (all idempotent)
# ───────────────────────────────────
install_snapd() {
  echo "🔧 Installing snapd…"
  apt_install snapd
}

install_ttyd() {
  echo "🔧 Ensuring ttyd snap…"
  need_snap ttyd || snap install ttyd --classic || [[ $? -eq 10 ]]
}

install_filebrowser() {
  echo "🔧 Ensuring File Browser…"
  need_cmd filebrowser || curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash
}

install_cli_prereqs() {
  echo "🔧 Installing CLI prereqs…"
  apt_install curl gnupg2 ca-certificates lsb-release ubuntu-keyring
}

install_nginx() {
  echo "🔧 Ensuring NGINX repo + pkg…"
  local keyring=/usr/share/keyrings/nginx-archive-keyring.gpg
  [[ -f $keyring ]] || curl -fsSL https://nginx.org/keys/nginx_signing.key | gpg --dearmor > "$keyring"

  local list=/etc/apt/sources.list.d/nginx.list
  grep -q "^deb .*nginx.org" "$list" 2>/dev/null || \
    echo "deb [signed-by=$keyring] http://nginx.org/packages/ubuntu $(lsb_release -cs) nginx" > "$list"

  apt-get update -qq
  need_cmd nginx || apt_install nginx
}

# ───────────────────────────────────
# 4) dependency resolution
# ───────────────────────────────────
echo "🔍 Checking dependencies…"
apt-get update -qq

need_cmd snap      || install_snapd
need_cmd curl || need_cmd gpg || install_cli_prereqs
need_snap ttyd     || install_ttyd
need_cmd filebrowser || install_filebrowser
need_cmd nginx     || install_nginx

TTYD_BIN=$(command -v ttyd)
FB_BIN=$(command -v filebrowser)

# ───────────────────────────────────
# 5) systemd units (overwrite-safe)
# ───────────────────────────────────
cat > /etc/systemd/system/ttyd.service <<EOF
[Unit]
Description=ttyd – Terminal over Web (port 7681)
After=network.target

[Service]
User=$USER_NAME
ExecStart=$TTYD_BIN --writable --port 7681 /bin/bash -l
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/filebrowser.service <<EOF
[Unit]
Description=File Browser (serving $USER_HOME on port 8080)
After=network.target

[Service]
User=$USER_NAME
WorkingDirectory=$USER_HOME
ExecStart=$FB_BIN \\
  -r $USER_HOME \\
  --address 0.0.0.0 \\
  --port 8080 \\
  --database $USER_HOME/.config/filebrowser.db
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# ───────────────────────────────────
# 6) Samba share setup
# ───────────────────────────────────
SMB_CONF=/etc/samba/smb.conf
echo "🔧 Ensuring Samba…"
need_cmd smbd || apt_install samba

echo "📂 Setting guest-read permissions on $USER_HOME…"
chmod o+rx "$USER_HOME"

# one-time smb.conf backup
[[ -f ${SMB_CONF}.orig ]] || cp "$SMB_CONF" "${SMB_CONF}.orig"

echo "🧹 Refreshing DCIM & Thymoeidolon blocks…"
awk '
  BEGIN {skip=0}
  /^\[(DCIM|Thymoeidolon)\]/{skip=1;next}
  /^\[.*\]/{skip=0}
  !skip
' "$SMB_CONF" > "${SMB_CONF}.tmp"
mv "${SMB_CONF}.tmp" "$SMB_CONF"

cat >> "$SMB_CONF" <<EOF

[DCIM]
   path = $BASE_DIR
   browsable = yes
   read only = no
   guest ok = yes
   force user = $USER_NAME

[Thymoeidolon]
   path = $USER_HOME
   browsable = yes
   read only = no
   guest ok = yes
   force user = $USER_NAME
EOF
systemctl restart smbd nmbd

# ───────────────────────────────────
# 7) enable + start services
# ───────────────────────────────────
systemctl daemon-reload
systemctl enable --now ttyd.service filebrowser.service

IP_ADDR=$(hostname -I | awk '{print $1}')
echo
echo "✅ All set!"
echo "   – ttyd        → http://$IP_ADDR:7681"
echo "   – File Browser → http://$IP_ADDR:8080  (serves $USER_HOME)"
echo "   – Samba shares live on $IP_ADDR"
