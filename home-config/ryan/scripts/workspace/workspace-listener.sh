#!/usr/bin/env bash
# Listens on Hyprland's event socket and nudges waybar's workspace buttons
# to redraw only when the active workspace actually changes, instead of
# waybar polling workspace-button-status.sh on a timer (was 0.3s -- that
# kept the CPU out of deep idle and burned battery for no reason).

set -uo pipefail

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && [ -d "$XDG_RUNTIME_DIR/hypr" ]; then
    export HYPRLAND_INSTANCE_SIGNATURE
    HYPRLAND_INSTANCE_SIGNATURE=$(ls -1 "$XDG_RUNTIME_DIR/hypr" 2>/dev/null | head -n 1)
fi

socket="$XDG_RUNTIME_DIR/hypr/${HYPRLAND_INSTANCE_SIGNATURE:-}/.socket2.sock"
if [ ! -S "$socket" ]; then
    exit 1
fi

socat -U - UNIX-CONNECT:"$socket" | while read -r line; do
    case "$line" in
        workspace\>\>*|focusedmon\>\>*)
            pkill -x -RTMIN+8 '(\.waybar-wrapped|waybar)' 2>/dev/null || true
            ;;
    esac
done

# Exit non-zero on socket EOF so systemd Restart=on-failure reconnects if Hyprland restarts
exit 1
