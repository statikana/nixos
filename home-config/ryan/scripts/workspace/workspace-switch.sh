#!/usr/bin/env bash
# this Hyprland build dispatches via its Lua API (hl.dsp.*), not the classic
# `dispatch workspace N` IPC syntax, so waybar's built-in hyprland/workspaces
# click handler can't switch workspaces here -- call the real dispatcher directly
hyprctl dispatch "hl.dsp.focus({ workspace = $1 })"
