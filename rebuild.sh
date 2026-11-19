#!/usr/bin/env bash
set -euo pipefail

EXEC_DIR=$(pwd)
CFG_DIR="/home/ryan/nixos"
NOW=$(date +'%Y-%m-%d %T')

cd "$CFG_DIR"
echo "(moved into ${CFG_DIR})"
echo "dont forget you can use reb-offline or \"rebuild.sh offline\" if you dont have internet to skip git push"

# Register any untracked files so Nix flakes include them, but only commit/push AFTER rebuild succeeds
nixfmt --indent=4 ~/nixos
git add -N .
sudo nixos-rebuild switch --flake "${CFG_DIR}#ryan-nixos"

git add .
if ! git diff --cached --quiet; then
    git commit -m "nixos-rebuild [$NOW]"
    if [[ "${1:-}" != "offline" ]]; then
        git push
    fi
else
    echo "(no config changes to commit)"
fi

cd "$EXEC_DIR"
echo "(moved back to ${EXEC_DIR})"
