#!/usr/bin/env bash
# Activates (starts and enables) common web/file services

set -euo pipefail

SERVICES=(
  ttyd
  smbd
  nmbd
  filebrowser
  nginx
)

echo "🔄 Starting and enabling services..."
for service in "${SERVICES[@]}"; do
  echo "▶️  $service"
  sudo systemctl start "$service"
  sudo systemctl enable "$service"
done

echo "✅ All services started and enabled."
