#!/usr/bin/env bash
set -euo pipefail

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
if [[ -x "$INSTALL_SCRIPT" ]]; then
  echo "🚀 Running Nephelodaemon/install.sh..."
  "$INSTALL_SCRIPT"
else
  echo "❌ '$INSTALL_SCRIPT' is missing or not executable."
  exit 1
fi
