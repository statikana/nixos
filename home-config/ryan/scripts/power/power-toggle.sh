#!/usr/bin/env bash
mode=$(cat $XDG_RUNTIME_DIR/power-mode 2>/dev/null || echo balanced)

case "$mode" in
    performance) next=balanced ;;
    balanced) next=saver ;;
    saver) next=performance ;;
    *) next=balanced ;;
esac

/home/ryan/nixos/home-config/ryan/scripts/power/power-"$next".sh
