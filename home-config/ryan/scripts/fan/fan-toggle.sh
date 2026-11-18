#!/usr/bin/env bash
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

mode=$(cat /run/fan-mode "$XDG_RUNTIME_DIR/fan-mode" 2>/dev/null | head -n 1)
[ -z "$mode" ] && mode="auto"

case "$mode" in
    quiet) next=max ;;
    auto)  next=quiet ;;
    max)   next=auto ;;
    *)     next=auto ;;
esac

/home/ryan/nixos/home-config/ryan/scripts/fan/fan-"$next".sh
