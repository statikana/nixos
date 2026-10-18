#!/usr/bin/env bash
# permission via udev/tmpfiles rule in modules/services.nix (power_ctl group)
echo "balanced" | tee $XDG_RUNTIME_DIR/power-mode >/dev/null
echo "balanced" | tee /sys/firmware/acpi/platform_profile >/dev/null
sudo systemctl start undervolt-balanced.service
