#!/usr/bin/env bash
# permission via tmpfiles rule in modules/services.nix (power_ctl group)
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
printf "balanced\n" > "$XDG_RUNTIME_DIR/power-mode"
echo "balanced" | tee /sys/firmware/acpi/platform_profile >/dev/null
sudo systemctl start undervolt-balanced.service
pkill -x -RTMIN+9 '(\.waybar-wrapped|waybar)' 2>/dev/null || true
