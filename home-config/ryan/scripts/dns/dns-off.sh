#!/usr/bin/env bash
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

if [ ! -e /etc/systemd/system/dns-proxy-off.service ]; then
    hyprctl notify 3 6000 "rgb(f38ba8)" "DNS Proxy units not installed yet — run: sudo nixos-rebuild switch --flake ~/nixos" >/dev/null 2>&1
    rm -f "$XDG_RUNTIME_DIR/dns-mode"
    pkill -RTMIN+11 waybar
    exit 1
fi

if sudo systemctl start dns-proxy-off.service; then
    echo "off" > "$XDG_RUNTIME_DIR/dns-mode"
    hyprctl notify 1 2500 "rgb(94e2d5)" "DNS Proxy: Off (Standard DHCP DNS & Direct IP)" >/dev/null 2>&1
else
    hyprctl notify 3 5000 "rgb(f38ba8)" "Failed to switch DNS Proxy to Off" >/dev/null 2>&1
fi

pkill -RTMIN+11 waybar
