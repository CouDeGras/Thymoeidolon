#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# Require root privileges
# ─────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
  echo "⚠️  Re-running with sudo..."
  exec sudo bash "$0" "$@"
fi

REPOS=(
  "https://github.com/CouDeGras/Nephelodaemon.git"
  "https://github.com/CouDeGras/Photochromata.git"
)

# ─────────────────────────────────────────────────────────────
# Clone repositories if not already present
# ─────────────────────────────────────────────────────────────
for repo in "${REPOS[@]}"; do
  dir=$(basename "$repo" .git)
  if [[ -d "$dir" ]]; then
    echo "✅ Repository '$dir' already exists. Skipping clone."
  else
    echo "📥 Cloning '$repo'..."
    git clone "$repo"
  fi
done

# ─────────────────────────────────────────────────────────────
# Run install script for Nephelodaemon
# ─────────────────────────────────────────────────────────────
INSTALL_SCRIPT="./Nephelodaemon/install.sh"
if [[ -f "$INSTALL_SCRIPT" ]]; then
  echo "🚀 Running Nephelodaemon/install.sh..."
  sudo bash "$INSTALL_SCRIPT"
else
  echo "❌ '$INSTALL_SCRIPT' not found."
  exit 1
fi
echo "✅ Thymoeidolon: Installation complete."