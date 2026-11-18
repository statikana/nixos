#!/usr/bin/env bash
# Manage Thunderbolt / DisplayPort / HDMI screen casting & multi-monitor projection in Hyprland.
# Usage:
#   display-cast.sh <laptop|mirror|extend|external|detect>

set -uo pipefail

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
if [ -z "${WAYLAND_DISPLAY:-}" ]; then
    wl_sock=$(ls -1 "$XDG_RUNTIME_DIR"/wayland-* 2>/dev/null | grep -v '\.lock$' | head -n 1 || true)
    [ -n "$wl_sock" ] && export WAYLAND_DISPLAY="$(basename "$wl_sock")"
fi
if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && [ -d "$XDG_RUNTIME_DIR/hypr" ]; then
    export HYPRLAND_INSTANCE_SIGNATURE="$(ls -1 "$XDG_RUNTIME_DIR/hypr" 2>/dev/null | head -n 1 || true)"
fi

MODE_FILE="$XDG_RUNTIME_DIR/display-mode"
DGPU_CTRL="/sys/bus/pci/devices/0000:01:00.0/power/control"

edp_mode() {
    local ac
    ac=$(cat /sys/class/power_supply/AC/online 2>/dev/null || echo 1)
    if [ "$ac" = "1" ]; then
        echo "2560x1600@165.02"
    else
        echo "2560x1600@60.01"
    fi
}

list_externals() {
    hyprctl monitors all -j 2>/dev/null \
        | jq -r '.[] | select(.name | startswith("eDP") | not) | .name' 2>/dev/null || true
}

release_dgpu_if_unused() {
    if [ -w "$DGPU_CTRL" ]; then
        echo auto > "$DGPU_CTRL" 2>/dev/null || true
    fi
}

# On ThinkPad P1 Gen 5, Thunderbolt 4 DP Alt-Mode lanes (DP-5 / DP-6) route through
# the NVIDIA RTX A2000 (0000:01:00.0), which sleeps in D3cold on battery/idle.
# Wake it briefly and trigger DRM connector probing so hotplugged sinks register.
wake_and_probe() {
    if [ -w "$DGPU_CTRL" ]; then
        echo on > "$DGPU_CTRL" 2>/dev/null || true
    fi
    command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1 || true
    cat /sys/class/drm/card*-DP-*/status /sys/class/drm/card*-HDMI-*/status >/dev/null 2>&1 || true

    local exts=""
    for _ in 1 2 3 4 5 6 7 8; do
        exts=$(list_externals)
        if [ -n "$exts" ]; then
            return 0
        fi
        sleep 0.22
        cat /sys/class/drm/card*-DP-*/status /sys/class/drm/card*-HDMI-*/status >/dev/null 2>&1 || true
    done
    return 1
}

ensure_externals() {
    local exts
    exts=$(list_externals)
    if [ -z "$exts" ]; then
        wake_and_probe || true
        exts=$(list_externals)
    fi
    printf "%s" "$exts"
}

ACTION="${1:-mirror}"

case "$ACTION" in
    laptop)
        hyprctl keyword monitor "eDP-1,$(edp_mode),auto,1.25" >/dev/null 2>&1 || true
        while IFS= read -r ext; do
            [ -n "$ext" ] || continue
            hyprctl keyword monitor "${ext},disable" >/dev/null 2>&1 || true
        done <<< "$(list_externals)"
        release_dgpu_if_unused
        echo "laptop" > "$MODE_FILE"
        ;;

    mirror)
        exts=$(ensure_externals)
        if [ -z "$exts" ]; then
            release_dgpu_if_unused
            hyprctl notify 0 3000 "rgb(f9e2af)" "Screen Cast: No Thunderbolt / external display detected" >/dev/null 2>&1 || true
            exit 1
        fi
        hyprctl keyword monitor "eDP-1,$(edp_mode),auto,1.25" >/dev/null 2>&1 || true
        first_ext=""
        while IFS= read -r ext; do
            [ -n "$ext" ] || continue
            [ -z "$first_ext" ] && first_ext="$ext"
            hyprctl keyword monitor "${ext},preferred,auto,1,mirror,eDP-1" >/dev/null 2>&1 || true
        done <<< "$exts"
        echo "mirror" > "$MODE_FILE"
        hyprctl notify 1 2500 "rgb(89b4fa)" "Screen Cast: Mirroring eDP-1 → ${first_ext}" >/dev/null 2>&1 || true
        ;;

    extend)
        exts=$(ensure_externals)
        if [ -z "$exts" ]; then
            release_dgpu_if_unused
            hyprctl notify 0 3000 "rgb(f9e2af)" "Screen Cast: No Thunderbolt / external display detected" >/dev/null 2>&1 || true
            exit 1
        fi
        hyprctl keyword monitor "eDP-1,$(edp_mode),auto,1.25" >/dev/null 2>&1 || true
        first_ext=""
        while IFS= read -r ext; do
            [ -n "$ext" ] || continue
            [ -z "$first_ext" ] && first_ext="$ext"
            hyprctl keyword monitor "${ext},preferred,auto,1.25" >/dev/null 2>&1 || true
        done <<< "$exts"
        echo "extend" > "$MODE_FILE"
        hyprctl notify 1 2500 "rgb(89b4fa)" "Screen Cast: Extended desktop → ${first_ext}" >/dev/null 2>&1 || true
        ;;

    external)
        exts=$(ensure_externals)
        if [ -z "$exts" ]; then
            release_dgpu_if_unused
            hyprctl notify 0 3000 "rgb(f9e2af)" "Screen Cast: Connect a Thunderbolt display first" >/dev/null 2>&1 || true
            exit 1
        fi
        first_ext=""
        while IFS= read -r ext; do
            [ -n "$ext" ] || continue
            [ -z "$first_ext" ] && first_ext="$ext"
            hyprctl keyword monitor "${ext},preferred,auto,1.25" >/dev/null 2>&1 || true
        done <<< "$exts"
        # Safety check: only disable internal panel once at least one external monitor is active
        if hyprctl monitors -j 2>/dev/null | jq -e '[.[] | select((.name | startswith("eDP") | not) and (.disabled == false))] | length > 0' >/dev/null 2>&1; then
            hyprctl keyword monitor "eDP-1,disable" >/dev/null 2>&1 || true
            echo "external" > "$MODE_FILE"
            hyprctl notify 1 2500 "rgb(89b4fa)" "Screen Cast: Thunderbolt display only (${first_ext})" >/dev/null 2>&1 || true
        else
            hyprctl notify 0 3000 "rgb(f38ba8)" "Screen Cast: External display failed to activate; keeping eDP-1 on" >/dev/null 2>&1 || true
            exit 1
        fi
        ;;

    detect)
        wake_and_probe || true
        exts=$(list_externals)
        if [ -z "$exts" ]; then
            release_dgpu_if_unused
            hyprctl notify 0 2500 "rgb(f9e2af)" "Thunderbolt scan: No external display connected" >/dev/null 2>&1 || true
            exit 1
        fi
        first_ext=$(printf "%s\n" "$exts" | head -n 1)
        hyprctl notify 1 2500 "rgb(a6e3a1)" "Thunderbolt display detected: ${first_ext}" >/dev/null 2>&1 || true
        ;;

    *)
        echo "Usage: $(basename "$0") <laptop|mirror|extend|external|detect>" >&2
        exit 1
        ;;
esac
