#!/usr/bin/env bash
# status/class for a single segment of the waybar power toggle; $1 is the segment's mode
mode=$(cat $XDG_RUNTIME_DIR/power-mode 2>/dev/null || echo balanced)
target="$1"
PROFILE=$(cat /sys/firmware/acpi/platform_profile 2>/dev/null)

case "$target" in
    performance) icon="󰓅" ;;
    saver) icon="󰾅" ;;
    *) icon="󰾆" ;;
esac

if [ "$mode" = "$target" ]; then
    class="active"
else
    class="inactive"
fi

printf '{"text":"%s","class":"%s","tooltip":"%s (ACPI profile: %s)"}\n' "$icon" "$class" "$target" "$PROFILE"
