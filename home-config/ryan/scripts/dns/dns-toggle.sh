#!/usr/bin/env bash
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

if systemctl is-active --quiet dnscrypt-proxy-tor.service 2>/dev/null; then
    mode="tor"
elif systemctl is-active --quiet dnscrypt-proxy-direct.service 2>/dev/null; then
    mode="direct"
else
    mode="off"
fi

case "$mode" in
    off)    next="direct" ;;
    direct) next="tor" ;;
    tor)    next="off" ;;
    *)      next="direct" ;;
esac

bash "/home/ryan/nixos/home-config/ryan/scripts/dns/dns-${next}.sh"
