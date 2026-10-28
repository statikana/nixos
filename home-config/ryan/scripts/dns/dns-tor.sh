#!/usr/bin/env bash
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

if [ ! -e /etc/systemd/system/dns-proxy-tor.service ]; then
    hyprctl notify 3 6000 "rgb(f38ba8)" "DNS/Tor units not installed yet — run: sudo nixos-rebuild switch --flake ~/nixos" >/dev/null 2>&1
    rm -f "$XDG_RUNTIME_DIR/dns-mode"
    pkill -RTMIN+11 waybar
    exit 1
fi

hyprctl notify 1 2500 "rgb(cba6f7)" "Starting Tor Transparent Proxy + DNSCrypt..." >/dev/null 2>&1

if sudo systemctl start dns-proxy-tor.service; then
    echo "tor" > "$XDG_RUNTIME_DIR/dns-mode"
    hyprctl notify 1 3500 "rgb(cba6f7)" "Tor Mode Active (TCP via TransPort 9040 + DoH via 9050)" >/dev/null 2>&1
else
    hyprctl notify 3 5000 "rgb(f38ba8)" "Failed to start Tor + DNSCrypt Proxy" >/dev/null 2>&1
fi

pkill -RTMIN+11 waybar
