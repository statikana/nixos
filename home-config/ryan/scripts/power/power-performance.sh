#!/usr/bin/env bash
# permission via udev/tmpfiles rule in modules/services.nix (power_ctl group)
echo "performance" | tee $XDG_RUNTIME_DIR/power-mode >/dev/null
echo "performance" | tee /sys/firmware/acpi/platform_profile >/dev/null
sudo systemctl start undervolt-performance.service
pkill -RTMIN+9 waybar
