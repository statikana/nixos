#!/usr/bin/env bash
# Packs occupied workspaces down to 1, 2, 3, ... in order, closing gaps left
# by empty workspaces (e.g. windows on 2 and 4 become 1 and 2). The dispatch
# string is parsed as Lua by this Hyprland build (see workspace-switch.sh),
# and its window.move/focus dispatchers only accept targeting via the
# `window = "address:0x..."` field -- an `address` field is silently ignored
# and the call falls back to acting on the focused window instead.
set -euo pipefail

clients=$(hyprctl clients -j)
active_before=$(hyprctl activeworkspace -j | jq -r '.id')

mapfile -t occupied < <(echo "$clients" | jq -r '[.[].workspace.id] | map(select(. > 0)) | unique | sort | .[]')

new_active="$active_before"

for i in "${!occupied[@]}"; do
    old_id="${occupied[$i]}"
    new_id=$((i + 1))

    if [ "$old_id" = "$active_before" ]; then
        new_active="$new_id"
    fi

    [ "$old_id" = "$new_id" ] && continue

    echo "$clients" | jq -r --argjson old "$old_id" '.[] | select(.workspace.id == $old) | .address' |
        while IFS= read -r addr; do
            [ -z "$addr" ] && continue
            hyprctl dispatch "hl.dsp.window.move({ workspace = $new_id, window = \"address:$addr\", silent = true })" >/dev/null
        done
done

if [ "$new_active" != "$active_before" ]; then
    hyprctl dispatch "hl.dsp.focus({ workspace = $new_active })" >/dev/null
fi

pkill -RTMIN+8 waybar
