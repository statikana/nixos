#!/usr/bin/env bash
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

if [ ! -e /etc/systemd/system/dns-proxy-direct.service ]; then
    hyprctl notify 3 6000 "rgb(f38ba8)" "DNS Proxy units not installed yet — run: sudo nixos-rebuild switch --flake ~/nixos" >/dev/null 2>&1
    rm -f "$XDG_RUNTIME_DIR/dns-mode"
    pkill -RTMIN+11 waybar
    exit 1
fi

if sudo systemctl start dns-proxy-direct.service; then
    echo "direct" > "$XDG_RUNTIME_DIR/dns-mode"
    hyprctl notify 1 2500 "rgb(74c7ec)" "DNS Proxy: Direct Cloudflare DoH (127.0.0.1:53)" >/dev/null 2>&1
else
    hyprctl notify 3 5000 "rgb(f38ba8)" "Failed to start Direct DNSCrypt Proxy" >/dev/null 2>&1
fi

pkill -RTMIN+11 waybar
