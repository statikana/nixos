#!/usr/bin/env bash
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

if [ ! -e /etc/systemd/system/dns-proxy-tor.service ]; then
    hyprctl notify 3 6000 "rgb(f38ba8)" "DNS/Tor units not installed yet — run: sudo nixos-rebuild switch --flake ~/nixos" >/dev/null 2>&1
    pkill -x -RTMIN+11 '(\.waybar-wrapped|waybar)' 2>/dev/null || true
    exit 1
fi

hyprctl notify 1 2500 "rgb(cba6f7)" "Starting Tor Transparent Proxy + .onion DNS + DoH..." >/dev/null 2>&1

if sudo systemctl start dns-proxy-tor.service; then
    hyprctl notify 1 3500 "rgb(cba6f7)" "Tor Mode Active (TransPort 9040 + .onion DNSPort 9053 + DoH)" >/dev/null 2>&1
else
    hyprctl notify 3 5000 "rgb(f38ba8)" "Failed to start Tor + DNSCrypt Proxy" >/dev/null 2>&1
fi

pkill -x -RTMIN+11 '(\.waybar-wrapped|waybar)' 2>/dev/null || true
