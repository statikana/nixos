#!/usr/bin/env bash
mode=$(cat $XDG_RUNTIME_DIR/fan-mode 2>/dev/null || echo auto)
RPM=$(cat /proc/acpi/ibm/fan | grep -oP "speed:\s*\K[0-9]+")

case "$mode" in
    quiet)
        printf "{\"text\":\"󰠝 <span>quiet</span>\",\"class\":\"quiet\",\"tooltip\":\"$RPM rpm\"}\n"
        ;;
    auto)
        printf "{\"text\":\"󱜝 <span>auto</span>\",\"class\":\"auto\",\"tooltip\":\"$RPM rpm\"}\n"
        ;;
    max)
        printf "{\"text\":\"󱜝 <span>max</span>\",\"class\":\"max\",\"tooltip\":\"$RPM rpm\"}\n"
        ;;
    *)
        printf "{\"text\":\"<span>?</span>\",\"class\":\"unknown\",\"tooltip\":\"$RPM rpm\"}\n"
        ;;
esac