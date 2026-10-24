#!/usr/bin/env bash
# permission via udev/tmpfiles rule in modules/services.nix (power_ctl group)
echo "saver" | tee $XDG_RUNTIME_DIR/power-mode >/dev/null
echo "low-power" | tee /sys/firmware/acpi/platform_profile >/dev/null
sudo systemctl start undervolt-saver.service
pkill -RTMIN+9 waybar
