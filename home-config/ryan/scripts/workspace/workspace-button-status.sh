#!/usr/bin/env bash
# status/class for a single workspace button; $1 is the workspace id
id="$1"
active=$(hyprctl activeworkspace -j | jq -r '.id')

case "$id" in
    1) icon="一" ;;
    2) icon="二" ;;
    3) icon="三" ;;
    4) icon="四" ;;
    5) icon="五" ;;
    6) icon="六" ;;
    7) icon="七" ;;
    8) icon="八" ;;
    9) icon="九" ;;
    *) icon="$id" ;;
esac

if [ "$active" = "$id" ]; then
    class="active"
else
    class="inactive"
fi

printf '{"text":"%s","class":"%s","tooltip":"workspace %s"}\n' "$icon" "$class" "$id"
