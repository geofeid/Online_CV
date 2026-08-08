#!/usr/bin/env bash
# Sync the built dist/ into the OnlineCV repo working copy, replacing the old
# hand-written site while keeping its GitHub Pages URL (geofeid.github.io/OnlineCV/).
# Review `git status` in OnlineCV afterwards, then commit & push manually.
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
target="${1:-$here/../OnlineCV}"

if [ ! -d "$target/.git" ]; then
  echo "Target $target is not a git repo" >&2
  exit 1
fi
if [ ! -f "$here/dist/index.html" ]; then
  echo "dist/index.html missing - run 'npm run build:pdf' first" >&2
  exit 1
fi

rsync -av --delete \
  --exclude='.git' \
  --exclude='.github' \
  --exclude='.gitignore' \
  --exclude='.remember' \
  --exclude='.claude' \
  "$here/dist/" "$target/"

echo
echo "Synced. Now review:  cd '$target' && git status"
