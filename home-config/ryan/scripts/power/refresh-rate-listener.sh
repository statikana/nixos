#!/usr/bin/env bash
# Switches display refresh rate, Hyprland visual effects (blur/shadows/opacity/animations),
# and CPU power profile only when AC online status actually flips between 0 and 1.
# Previously, udevadm monitor triggered `hyprctl reload` on every BAT0 capacity %
# change (~every 30-60s while discharging), waking DRM devices and spiking CPU.

ensure_hypr_sig() {
    export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && [ -d "$XDG_RUNTIME_DIR/hypr" ]; then
        export HYPRLAND_INSTANCE_SIGNATURE
        HYPRLAND_INSTANCE_SIGNATURE=$(ls -1 "$XDG_RUNTIME_DIR/hypr" 2>/dev/null | head -n 1)
    fi
}

last_ac=""

apply_if_changed() {
    local ac
    ac=$(cat /sys/class/power_supply/AC/online 2>/dev/null || echo 1)
    if [ "$ac" = "$last_ac" ]; then
        return
    fi
    last_ac="$ac"
    ensure_hypr_sig

    if [ "$ac" = "1" ]; then
        hyprctl --batch "keyword monitor eDP-1,2560x1600@165.02,auto,1.25 ; keyword decoration:blur:enabled true ; keyword decoration:shadow:enabled true ; keyword decoration:inactive_opacity 0.95 ; keyword animations:enabled true" >/dev/null 2>&1
        /home/ryan/nixos/home-config/ryan/scripts/power/power-balanced.sh >/dev/null 2>&1
    else
        hyprctl --batch "keyword monitor eDP-1,2560x1600@60.01,auto,1.25 ; keyword decoration:blur:enabled false ; keyword decoration:shadow:enabled false ; keyword decoration:inactive_opacity 1.0 ; keyword animations:enabled false" >/dev/null 2>&1
        /home/ryan/nixos/home-config/ryan/scripts/power/power-saver.sh >/dev/null 2>&1
    fi
}

# Apply immediately on service start
apply_if_changed

udevadm monitor --udev --subsystem-match=power_supply | while read -r line; do
    case "$line" in
        UDEV*) apply_if_changed ;;
    esac
done
