#!/usr/bin/env bash
# Toggle systemd-logind lid-switch & sleep inhibitor so the laptop stays running
# when the lid is closed (blocks both logind lid-close suspend and hypridle's
# idle suspend timeout while still allowing screen lock / DPMS off).
#
# Usage:
#   lid-inhibit.sh <keep|on|suspend|off|toggle|status>

set -uo pipefail

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=${XDG_RUNTIME_DIR}/bus}"
export PATH="/run/wrappers/bin:/home/ryan/.nix-profile/bin:/etc/profiles/per-user/ryan/bin:/run/current-system/sw/bin:${PATH:-}"

if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && [ -d "$XDG_RUNTIME_DIR/hypr" ]; then
    export HYPRLAND_INSTANCE_SIGNATURE="$(ls -1 "$XDG_RUNTIME_DIR/hypr" 2>/dev/null | head -n 1 || true)"
fi

UNIT_NAME="waybar-lid-inhibit"
UNIT="${UNIT_NAME}.service"

is_active() {
    systemctl --user is-active --quiet "$UNIT"
}

notify() {
    local color="$1"
    local msg="$2"
    command -v hyprctl >/dev/null 2>&1 || return 0
    [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || return 0
    hyprctl notify 1 2500 "$color" "$msg" >/dev/null 2>&1 || true
}

enable_inhibit() {
    if is_active; then
        return 0
    fi
    systemctl --user reset-failed "$UNIT" >/dev/null 2>&1 || true
    local inhibit_bin sleep_bin
    inhibit_bin="$(command -v systemd-inhibit)"
    sleep_bin="$(command -v sleep)"
    systemd-run --user --collect \
        --unit="$UNIT_NAME" \
        --description="Keep laptop running when lid is closed" \
        "$inhibit_bin" \
            --what=handle-lid-switch:sleep \
            --who="Waybar Flyout" \
            --why="Keep laptop running with lid closed" \
            --mode=block \
            "$sleep_bin" infinity >/dev/null 2>&1
    notify "rgb(89b4fa)" "Lid Close: Laptop will stay running"
}

disable_inhibit() {
    local was_active=0
    if is_active; then
        was_active=1
        systemctl --user stop "$UNIT" >/dev/null 2>&1 || true
    fi
    systemctl --user reset-failed "$UNIT" >/dev/null 2>&1 || true
    if [ "$was_active" -eq 1 ]; then
        notify "rgb(a6adc8)" "Lid Close: Normal suspend restored"
    fi
}

ACTION="${1:-status}"

case "$ACTION" in
    keep|on|enable)
        enable_inhibit
        ;;
    suspend|off|disable)
        disable_inhibit
        ;;
    toggle)
        if is_active; then
            disable_inhibit
        else
            enable_inhibit
        fi
        ;;
    status)
        if is_active; then
            echo "keep"
        else
            echo "suspend"
        fi
        ;;
    *)
        echo "Usage: $0 <keep|on|suspend|off|toggle|status>" >&2
        exit 2
        ;;
esac
