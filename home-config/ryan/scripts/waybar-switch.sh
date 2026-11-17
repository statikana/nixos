#!/usr/bin/env bash
# Switch ~/.config/waybar symlinks between the 'minimal' and 'full' Waybar configs.
# Usage:
#   waybar-switch.sh            # toggle between minimal and full
#   waybar-switch.sh minimal    # activate minimal bar
#   waybar-switch.sh full       # activate original full bar
#   waybar-switch.sh status     # print currently active profile

set -euo pipefail

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
if [ -z "${WAYLAND_DISPLAY:-}" ]; then
    wl_sock=$(ls -1 "$XDG_RUNTIME_DIR"/wayland-* 2>/dev/null | grep -v '\.lock$' | head -n 1 || true)
    [ -n "$wl_sock" ] && export WAYLAND_DISPLAY="$(basename "$wl_sock")"
fi
if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && [ -d "$XDG_RUNTIME_DIR/hypr" ]; then
    export HYPRLAND_INSTANCE_SIGNATURE="$(ls -1 "$XDG_RUNTIME_DIR/hypr" 2>/dev/null | head -n 1 || true)"
fi

CFG_DIR="$HOME/.config/waybar"
BASE_DIR="/home/ryan/nixos/home-config/ryan/waybar-config"
FLYOUT_CTL="/home/ryan/nixos/home-config/ryan/scripts/flyout/flyout-ctl.sh"

current_target=$(readlink "$CFG_DIR/config.jsonc" 2>/dev/null || echo "")
if [[ "$current_target" == *"/minimal/"* ]]; then
    current="minimal"
else
    current="full"
fi

mode="${1:-toggle}"
case "$mode" in
    status)
        echo "$current"
        exit 0
        ;;
    toggle)
        if [ "$current" = "minimal" ]; then
            target="full"
        else
            target="minimal"
        fi
        ;;
    minimal|full)
        target="$mode"
        ;;
    *)
        echo "Usage: $(basename "$0") [toggle|minimal|full|status]" >&2
        exit 1
        ;;
esac

mkdir -p "$CFG_DIR"
[ -x "$FLYOUT_CTL" ] && "$FLYOUT_CTL" close >/dev/null 2>&1 || true

if [ "$target" = "minimal" ]; then
    ln -sfn "$BASE_DIR/minimal/config.jsonc" "$CFG_DIR/config.jsonc"
    ln -sfn "$BASE_DIR/minimal/style.css" "$CFG_DIR/style.css"
    label="Minimal"
else
    ln -sfn "$BASE_DIR/config.jsonc" "$CFG_DIR/config.jsonc"
    ln -sfn "$BASE_DIR/style.css" "$CFG_DIR/style.css"
    label="Full"
fi

pkill -x '(\.waybar-wrapped|waybar)' 2>/dev/null || true
for _ in {1..20}; do
    pgrep -x '(\.waybar-wrapped|waybar)' >/dev/null 2>&1 || break
    sleep 0.05
done

setsid -f waybar >/dev/null 2>&1

hyprctl notify 1 2000 "rgb(89b4fa)" "Waybar switched to ${label}" >/dev/null 2>&1 || true
echo "Switched Waybar to: $target"
