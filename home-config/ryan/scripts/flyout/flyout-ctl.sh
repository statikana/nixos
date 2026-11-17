#!/usr/bin/env bash
# Fast controller for the GTK4 Layer-Shell Waybar Flyout Center.
# Usage:
#   flyout-ctl.sh toggle <hwmon|quick|power>
#   flyout-ctl.sh open   <hwmon|quick|power>
#   flyout-ctl.sh close
#   flyout-ctl.sh quit

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
if [ -z "${WAYLAND_DISPLAY:-}" ]; then
    wl_sock=$(ls -1 "$XDG_RUNTIME_DIR"/wayland-* 2>/dev/null | grep -v '\.lock$' | head -n 1)
    [ -n "$wl_sock" ] && export WAYLAND_DISPLAY="$(basename "$wl_sock")"
fi
if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && [ -d "$XDG_RUNTIME_DIR/hypr" ]; then
    export HYPRLAND_INSTANCE_SIGNATURE="$(ls -1 "$XDG_RUNTIME_DIR/hypr" 2>/dev/null | head -n 1)"
fi

FLYOUT_PY="/home/ryan/nixos/home-config/ryan/scripts/flyout/waybar-flyout.py"
SOCK_PATH="$XDG_RUNTIME_DIR/waybar-flyout.sock"
STAMP_FILE="$XDG_RUNTIME_DIR/waybar-flyout.stamp"
ENV_CACHE="$XDG_RUNTIME_DIR/waybar-flyout-env.sh"

ACTION="${1:-toggle}"
TAB="${2:-quick}"

send_sock() {
    printf "%s\n" "$1" | socat - "UNIX-CONNECT:${SOCK_PATH}" 2>/dev/null
}

cur_mtime=$(stat -c %Y "$FLYOUT_PY" 2>/dev/null || echo 0)
old_mtime=$(cat "$STAMP_FILE" 2>/dev/null || echo 0)

# Restart warm daemon automatically if waybar-flyout.py was updated
if [ -S "$SOCK_PATH" ] && [ "$cur_mtime" != "$old_mtime" ]; then
    send_sock "quit" || true
    rm -f "$SOCK_PATH"
    sleep 0.08
fi

if [ "$ACTION" = "close" ] || [ "$ACTION" = "quit" ]; then
    [ -S "$SOCK_PATH" ] && send_sock "$ACTION" || true
    exit 0
fi

# Fast path: warm daemon is already running (<5ms wakeup)
if [ -S "$SOCK_PATH" ] && send_sock "${ACTION}:${TAB}"; then
    exit 0
fi

# Cold start: launch warm daemon and open the requested tab immediately
rm -f "$SOCK_PATH"
printf "%s\n" "$cur_mtime" > "$STAMP_FILE"

if command -v waybar-flyout-python >/dev/null 2>&1; then
    setsid -f waybar-flyout-python "$FLYOUT_PY" --tab "$TAB" >/dev/null 2>&1
    exit 0
fi

# Pre-rebuild fallback: resolve GTK4 + Gtk4LayerShell + PyGObject from /nix/store once per session
if [ ! -s "$ENV_CACHE" ]; then
    py_ver=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
    lsh_dir=$(ls -d /nix/store/*-gtk4-layer-shell-* 2>/dev/null | grep -vE '(-dev|\.drv)$' | tail -n 1)
    gtk4_dir=$(nix-store -q --references "$lsh_dir" 2>/dev/null | grep -E -- '-gtk4-[0-9]' | head -n 1)
    pyg_dir=$(ls -d /nix/store/*-python${py_ver}-pygobject-* 2>/dev/null | grep -vE '(-dev|\.drv)$' | tail -n 1)
    gobj_dir=$(ls -d /nix/store/*-gobject-introspection-1.* 2>/dev/null | grep -vE '(-dev|\.drv)$' | tail -n 1)

    refs=$(nix-store -q -R "$lsh_dir" "$pyg_dir" ${gobj_dir:+"$gobj_dir"} 2>/dev/null)
    typelibs=$(for r in $refs; do [ -d "$r/lib/girepository-1.0" ] && echo "$r/lib/girepository-1.0"; done | paste -sd: -)

    cat > "$ENV_CACHE" <<EOF
export LD_PRELOAD="${lsh_dir}/lib/libgtk4-layer-shell.so"
export LD_LIBRARY_PATH="${lsh_dir}/lib:${gtk4_dir}/lib"
export PYTHONPATH="${pyg_dir}/lib/python${py_ver}/site-packages"
export GI_TYPELIB_PATH="${typelibs}"
EOF
fi

# shellcheck disable=SC1090
source "$ENV_CACHE"
setsid -f python3 "$FLYOUT_PY" --tab "$TAB" >/dev/null 2>&1
