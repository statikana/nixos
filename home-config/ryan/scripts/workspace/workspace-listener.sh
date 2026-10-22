#!/usr/bin/env bash
# Listens on Hyprland's event socket and nudges waybar's workspace buttons
# to redraw only when the active workspace actually changes, instead of
# waybar polling workspace-button-status.sh on a timer (was 0.3s -- that
# kept the CPU out of deep idle and burned battery for no reason).

socket="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

socat -U - UNIX-CONNECT:"$socket" | while read -r line; do
    case "$line" in
        workspace\>\>*|focusedmon\>\>*)
            pkill -RTMIN+8 waybar
            ;;
    esac
done
