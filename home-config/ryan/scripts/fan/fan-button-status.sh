#!/usr/bin/env bash
# status/class for a single segment of the waybar fan dropdown; $1 is the segment's mode
mode=$(cat $XDG_RUNTIME_DIR/fan-mode 2>/dev/null || echo auto)
target="$1"

case "$target" in
    quiet) icon="󰠝" ;;
    max) icon="󱜝" ;;
    *) icon="󱜝" ;;
esac

if [ "$mode" = "$target" ]; then
    class="active"
else
    class="inactive"
fi

printf '{"text":"%s","class":"%s","tooltip":"%s"}\n' "$icon" "$class" "$target"
