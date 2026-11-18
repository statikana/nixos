#!/usr/bin/env bash
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

if [ -e /etc/systemd/system/thinkfan-auto.service ]; then
    sudo /run/current-system/sw/bin/systemctl start thinkfan-auto.service
else
    echo "level auto" > /proc/acpi/ibm/fan 2>/dev/null || true
    sudo /run/current-system/sw/bin/systemctl start thinkfan.service
fi
printf "auto\n" > "$XDG_RUNTIME_DIR/fan-mode"
pkill -x -RTMIN+10 '(\.waybar-wrapped|waybar)' 2>/dev/null || true
