#!/usr/bin/env bash
mode=$(cat $XDG_RUNTIME_DIR/power-mode 2>/dev/null || echo balanced)
PROFILE=$(cat /sys/firmware/acpi/platform_profile 2>/dev/null)

case "$mode" in
    performance)
        printf "{\"text\":\"󰓅 <span>performance</span>\",\"class\":\"performance\",\"tooltip\":\"ACPI profile: $PROFILE\"}\n"
        ;;
    saver)
        printf "{\"text\":\"󰾅 <span>saver</span>\",\"class\":\"saver\",\"tooltip\":\"ACPI profile: $PROFILE\"}\n"
        ;;
    *)
        printf "{\"text\":\"󰾆 <span>balanced</span>\",\"class\":\"balanced\",\"tooltip\":\"ACPI profile: $PROFILE\"}\n"
        ;;
esac
