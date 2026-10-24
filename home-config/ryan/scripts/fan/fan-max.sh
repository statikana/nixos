#!/usr/bin/env bash
# permission in security.nix to start/stop thinkfan
sudo /run/current-system/sw/bin/systemctl stop thinkfan.service
echo "max" | tee $XDG_RUNTIME_DIR/fan-mode >/dev/null
echo "level 7" | tee /proc/acpi/ibm/fan >/dev/null
pkill -RTMIN+10 waybar
