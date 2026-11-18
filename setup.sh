#!/usr/bin/env bash
set -euo pipefail

# random setup things to do when first initializing
# this isn't exhaustive but i'll update it when I need to
# obviously I try to avoid these things when necessary
# since nixos is supposed to be declarative

# Make scripts executable (e.g. the ones used in waybar)
CONFIG_BASE="/home/ryan/nixos"
SCRIPT_BASE="${CONFIG_BASE}/home-config/ryan/scripts"
find "${SCRIPT_BASE}" -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod +x {} +
chmod +x "${CONFIG_BASE}/rebuild.sh"
