#!/usr/bin/env bash

if (( $(pgrep -xc '(\.waybar-wrapped|waybar)') != 0 )); then
    /home/ryan/nixos/home-config/ryan/scripts/flyout/flyout-ctl.sh close 2>/dev/null || true
    pkill -x '(\.waybar-wrapped|waybar)'
else
    waybar&
fi