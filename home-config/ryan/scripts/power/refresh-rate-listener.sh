#!/usr/bin/env bash
# Drops the panel to 60Hz on battery and restores 165Hz on AC. A 2560x1600
# panel pushing 165 frames/sec through the compositor costs real battery for
# no benefit during normal desktop/battery use, so only run it full-rate
# when actually plugged in.
# display.lua reads AC state itself and picks the mode; reloading re-evaluates it
apply() {
    hyprctl reload
}

udevadm monitor --udev --subsystem-match=power_supply | while read -r line; do
    case "$line" in
        UDEV*) apply ;;
    esac
done
