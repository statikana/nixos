#!/usr/bin/env bash
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

mode=$(cat /run/power-mode "$XDG_RUNTIME_DIR/power-mode" 2>/dev/null | head -n 1)
[ -z "$mode" ] && mode="balanced"

case "$mode" in
    performance) next=balanced ;;
    balanced)    next=saver ;;
    saver)       next=performance ;;
    *)           next=balanced ;;
esac

/home/ryan/nixos/home-config/ryan/scripts/power/power-"$next".sh
