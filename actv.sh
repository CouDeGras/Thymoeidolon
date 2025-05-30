#!/usr/bin/env bash
# Temporarily starts services for usage

set -euo pipefail

SERVICES=(
  ttyd
  smbd
  nmbd
  filebrowser
  nginx
)

echo "🔄 Starting services..."
for service in "${SERVICES[@]}"; do
  echo "▶️  $service"
  sudo systemctl start "$service"
done

echo "✅ All services started."
