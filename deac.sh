#!/usr/bin/env bash
# Deactivates (stops and disables) common web/file services

set -euo pipefail

SERVICES=(
  ttyd
  smbd
  nmbd
  filebrowser
  nginx
)

echo "🔄 Stopping and disabling services..."
for service in "${SERVICES[@]}"; do
  echo "⛔️ $service"
  sudo systemctl stop "$service"
  sudo systemctl disable "$service"
done

echo "✅ All services stopped and disabled."
