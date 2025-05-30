#!/usr/bin/env bash
# Temporarily stops services to save power

set -euo pipefail

SERVICES=(
  ttyd
  smbd
  nmbd
  filebrowser
  nginx
)

echo "🔄 Stopping services..."
for service in "${SERVICES[@]}"; do
  echo "⛔️ $service"
  sudo systemctl stop "$service"
done

echo "✅ All services stopped."
