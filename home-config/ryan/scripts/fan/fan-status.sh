#!/usr/bin/env bash
mode=$(cat $XDG_RUNTIME_DIR/fan-mode 2>/dev/null || echo auto)
RPM=$(cat /proc/acpi/ibm/fan | grep -oP "speed:\s*\K[0-9]+")

case "$mode" in
    quiet)
        printf "{\"text\":\"󰠝 <span>quiet</span> [$RPM rpm]\",\"class\":\"quiet\"}\n"
        ;;
    auto)
        printf "{\"text\":\"󱜝 <span>auto</span> [$RPM rpm]\",\"class\":\"auto\"}\n"
        ;;
    max)
        printf "{\"text\":\"󱜝 <span>max</span> [$RPM rpm]\",\"class\":\"max\"}\n"
        ;;
    *)
        printf "{\"text\":\"<span>?</span> [$RPM rpm]\",\"class\":\"unknown\"}\n"
        ;;
esac