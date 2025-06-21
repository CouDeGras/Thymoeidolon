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
  "https://github.com/CouDeGras/Aktinoplanesiographema.git"
  "https://github.com/CouDeGras/Chromatodiethegraphema.git"
  "https://github.com/CouDeGras/Plegmasyndesmogramma.git"
)

# ─────────────────────────────────────────────────────────────
# Clone or update repositories
# ─────────────────────────────────────────────────────────────
for repo in "${REPOS[@]}"; do
  dir=$(basename "$repo" .git)

  if [[ -d "$dir" && -d "$dir/.git" ]]; then
    echo "🔄 Updating '$dir'..."
    (
      cd "$dir"
      git pull --ff-only
    )
  else
    if [[ -d "$dir" ]]; then
      echo "⚠️  '$dir' exists but is not a Git repo; removing and recloning..."
      rm -rf "$dir"
    fi
    echo "📥 Cloning '$repo'..."
    git clone "$repo"
  fi
done

# ─────────────────────────────────────────────────────────────
# Run install script in each cloned repo if found
# ─────────────────────────────────────────────────────────────
for repo in "${REPOS[@]}"; do
  dir=$(basename "$repo" .git)
  install_path="$dir/install.sh"

  if [[ -f "$install_path" ]]; then
    echo "🚀 Running '$install_path'..."
    bash "$install_path"
  else
    echo "ℹ️  No install script found in '$dir', skipping..."
  fi
done

echo "✅ All installations (if any) complete."

