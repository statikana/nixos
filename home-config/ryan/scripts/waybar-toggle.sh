#!/usr/bin/env bash

if (( $(pgrep -c waybar) != 0 )); then
    pkill waybar
else
    waybar&
fi