#!/usr/bin/env bash
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

if [ ! -e /etc/systemd/system/dns-proxy-warp.service ]; then
    hyprctl notify 3 6000 "rgb(f38ba8)" "DNS/WARP units not installed yet — run: sudo nixos-rebuild switch --flake ~/nixos" >/dev/null 2>&1
    rm -f "$XDG_RUNTIME_DIR/dns-mode"
    pkill -RTMIN+11 waybar
    exit 1
fi

hyprctl notify 1 2500 "rgb(fab387)" "Starting Cloudflare WARP WireGuard Tunnel + DoH..." >/dev/null 2>&1

if sudo systemctl start dns-proxy-warp.service; then
    echo "warp" > "$XDG_RUNTIME_DIR/dns-mode"
    hyprctl notify 1 3500 "rgb(fab387)" "WARP Mode Active (WireGuard warp0 + Cloudflare DoH)" >/dev/null 2>&1
else
    hyprctl notify 3 5000 "rgb(f38ba8)" "Failed to start Cloudflare WARP Tunnel" >/dev/null 2>&1
fi

pkill -RTMIN+11 waybar
