#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# 0) must run as root
# ─────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
  echo "⚠️  Please run this script as root (e.g. with sudo)."
  exit 1
fi

# ─────────────────────────────────────────────────────────────
# 1) helper utilities
# ─────────────────────────────────────────────────────────────
need_cmd()   { command -v "$1" &>/dev/null; }   # returns 0 if cmd exists
apt_install() {
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@"
}

# ─────────────────────────────────────────────────────────────
# 2) dependency installers
# ─────────────────────────────────────────────────────────────
install_snapd() {
  echo "🔧 Installing snapd …"
  apt_install snapd
}

install_ttyd() {
  echo "🔧 Installing ttyd via snap …"
  snap install ttyd --classic
}

install_filebrowser() {
  echo "🔧 Installing File Browser …"
  curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash
}

install_cli_prereqs() {
  echo "🔧 Installing CLI prerequisites (curl, gnupg2, …) …"
  apt_install curl gnupg2 ca-certificates lsb-release ubuntu-keyring
}

install_nginx() {
  echo "🔧 Installing NGINX from official repo …"
  curl -fsSL https://nginx.org/keys/nginx_signing.key \
    | gpg --dearmor \
    | tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null

  echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] \
http://nginx.org/packages/ubuntu $(lsb_release -cs) nginx" \
    | tee /etc/apt/sources.list.d/nginx.list >/dev/null

  apt-get update
  apt_install nginx
}

# ─────────────────────────────────────────────────────────────
# 3) detect & install missing dependencies
# ─────────────────────────────────────────────────────────────
echo "🔍 Checking dependencies …"
apt-get update -qq

# snapd first (needed for ttyd)
if ! need_cmd snap; then
  install_snapd
fi

# basic CLI tools (curl et al.)
if ! need_cmd curl || ! need_cmd gpg; then
  install_cli_prereqs
fi

# ttyd
if ! need_cmd ttyd; then
  install_ttyd
fi

# File Browser
if ! need_cmd filebrowser; then
  install_filebrowser
fi

# nginx
if ! need_cmd nginx; then
  install_nginx
fi

# ─────────────────────────────────────────────────────────────
# 4) resolve the real, non-root user
# ─────────────────────────────────────────────────────────────
USER_NAME=${SUDO_USER:-${USER}}
HOME_DIR=$(getent passwd "$USER_NAME" | cut -d: -f6)

TTYD_BIN=$(command -v ttyd)
FB_BIN=$(command -v filebrowser)

# ─────────────────────────────────────────────────────────────
# 5) systemd unit: ttyd
# ─────────────────────────────────────────────────────────────
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

# ─────────────────────────────────────────────────────────────
# 6) systemd unit: File Browser
# ─────────────────────────────────────────────────────────────

cat > /etc/systemd/system/filebrowser.service <<EOF
[Unit]
Description=File Browser (serving $HOME_DIR on port 8080)
After=network.target

[Service]
User=$USER_NAME
WorkingDirectory=$HOME_DIR
ExecStart=$FB_BIN \\
  -r $HOME_DIR \\
  --address 0.0.0.0 \\
  --port 8080 \\
  --database $HOME_DIR/.config/filebrowser.db
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
# ─────────────────────────────────────────────────────────────
# 7) enable & start services
# ─────────────────────────────────────────────────────────────
systemctl daemon-reload
systemctl enable --now ttyd.service filebrowser.service

echo
echo "✅ All set!"
echo "   – ttyd      → http://<host>:7681"
echo "   – filebrowser → http://<host>:8080 (serves $HOME_DIR)"
echo
echo "Check status with:  systemctl status ttyd filebrowser nginx"
