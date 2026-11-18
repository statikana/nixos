#!/usr/bin/env bash
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

if [ -e /etc/systemd/system/thinkfan-max.service ]; then
    sudo /run/current-system/sw/bin/systemctl start thinkfan-max.service
else
    sudo /run/current-system/sw/bin/systemctl stop thinkfan.service
    echo "level disengaged" > /proc/acpi/ibm/fan 2>/dev/null || true
fi
printf "max\n" > "$XDG_RUNTIME_DIR/fan-mode"
pkill -x -RTMIN+10 '(\.waybar-wrapped|waybar)' 2>/dev/null || true
