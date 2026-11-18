#!/usr/bin/env bash
# Stylized Catppuccin Mocha Fan status & Pango tooltip for Waybar (Accent: Teal)
# - Reads /proc/acpi/ibm/thermal max sensor (exact same input thinkfan uses)
# - Parses the active ThinkFan YAML profile (/run/thinkfan-active.yaml, or falls back to
#   modules/services.nix pre-rebuild) and caches it in $XDG_RUNTIME_DIR/thinkfan-curve.cache

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
ACTIVE_YAML="/run/thinkfan-active.yaml"
SERVICES_NIX="/home/ryan/nixos/modules/services.nix"
CACHE_FILE="$XDG_RUNTIME_DIR/thinkfan-curve.cache"
STAMP_FILE="$XDG_RUNTIME_DIR/thinkfan-curve.stamp"

if [ -r "$ACTIVE_YAML" ]; then
    yaml_target=$(readlink -f "$ACTIVE_YAML" 2>/dev/null || echo "$ACTIVE_YAML")
    old_target=$(cat "$STAMP_FILE" 2>/dev/null || echo "")
    if [ ! -s "$CACHE_FILE" ] || [ "$yaml_target" != "$old_target" ]; then
        awk '
            /^levels:/ { in_lvl = 1; next }
            in_lvl && /^[^[:space:]-]/ { in_lvl = 0 }
            in_lvl && /^- -[[:space:]]*/ {
                if (ntok >= 3) printf "%s|%s|%s\n", tok[1], tok[2], tok[3]
                ntok = 1
                sub(/^- -[[:space:]]*/, "")
                tok[1] = $0
                next
            }
            in_lvl && /^[[:space:]]+-[[:space:]]*/ {
                sub(/^[[:space:]]+-[[:space:]]*/, "")
                tok[++ntok] = $0
            }
            END {
                if (ntok >= 3) printf "%s|%s|%s\n", tok[1], tok[2], tok[3]
            }
        ' "$ACTIVE_YAML" > "$CACHE_FILE" 2>/dev/null
        printf "%s\n" "$yaml_target" > "$STAMP_FILE"
    fi
elif [ ! -s "$CACHE_FILE" ] || [ "$SERVICES_NIX" -nt "$CACHE_FILE" ]; then
    awk '
        /thinkfan[[:space:]]*=/ { in_tf = 1 }
        in_tf && /levels[[:space:]]*=[[:space:]]*\[/ {
            in_lvl = 1
            sub(/.*levels[[:space:]]*=[[:space:]]*\[/, "")
        }
        in_lvl {
            sub(/#.*/, "")
            s = $0
            while (length(s) > 0) {
                if (match(s, /^[[:space:]]+/)) {
                    s = substr(s, RLENGTH + 1)
                } else if (substr(s, 1, 1) == "[") {
                    in_entry = 1
                    ntok = 0
                    s = substr(s, 2)
                } else if (substr(s, 1, 1) == "]") {
                    if (in_entry) {
                        if (ntok >= 3) printf "%s|%s|%s\n", tok[1], tok[2], tok[3]
                        in_entry = 0
                    } else {
                        in_lvl = 0
                        in_tf = 0
                        break
                    }
                    s = substr(s, 2)
                } else if (substr(s, 1, 1) == "\"") {
                    rest = substr(s, 2)
                    if (match(rest, /[^"]*"/)) {
                        val = substr(rest, 1, RLENGTH - 1)
                        s = substr(rest, RLENGTH + 1)
                    } else {
                        val = rest
                        s = ""
                    }
                    if (in_entry) tok[++ntok] = val
                } else if (match(s, /^[^[:space:]\[\]"]+/)) {
                    val = substr(s, 1, RLENGTH)
                    s = substr(s, RLENGTH + 1)
                    if (in_entry) tok[++ntok] = val
                } else {
                    s = substr(s, 2)
                }
            }
        }
    ' "$SERVICES_NIX" > "$CACHE_FILE" 2>/dev/null
fi

mode=$(cat /run/fan-mode "$XDG_RUNTIME_DIR/fan-mode" 2>/dev/null | head -n 1)
[ -z "$mode" ] && mode="auto"
RPM=$(grep -oP "speed:\s*\K[0-9]+" /proc/acpi/ibm/fan 2>/dev/null || echo 0)
LEVEL=$(awk '/^level:/ {print $2}' /proc/acpi/ibm/fan 2>/dev/null || echo "?")

read -r TEMP CPU_TEMP < <(
    awk '{
        max = $2
        for (i = 2; i <= NF; i++) if ($i > max) max = $i
        printf "%d %d\n", max, $2
    }' /proc/acpi/ibm/thermal 2>/dev/null
)
[ -z "$TEMP" ] && TEMP=40

m_quiet="<span foreground='#6c7086'>quiet</span>"
m_auto="<span foreground='#6c7086'>auto</span>"
m_max="<span foreground='#6c7086'>max</span>"

case "$mode" in
    quiet) m_quiet="<span foreground='#89b4fa' weight='bold'>[quiet]</span>" ;;
    max)   m_max="<span foreground='#f9e2af' weight='bold'>[max]</span>" ;;
    *)     m_auto="<span foreground='#94e2d5' weight='bold'>[auto]</span>" ;;
esac

if [ "${RPM:-0}" -eq 0 ] 2>/dev/null; then
    rpm_str="<span foreground='#a6e3a1' weight='bold'>0 RPM (Silent Off)</span>"
else
    rpm_str="<span foreground='#94e2d5' weight='bold'>${RPM} RPM</span>"
fi

# Build the curve rows dynamically from the cached ThinkFan profile levels
curve_rows=""
while IFS='|' read -r lvl down up; do
    [ -z "$lvl" ] && continue

    case "$lvl" in
        0)                   lvl_label="Level 0 (0 RPM Off)" ;;
        1|2|3|4|5|6|7)       lvl_label="Level ${lvl}" ;;
        *disengaged*|*full*) lvl_label="Disengaged (Max)" ;;
        *)                   lvl_label="${lvl}" ;;
    esac

    if [ "$up" -ge 200 ] 2>/dev/null; then
        range_label="${down}°C+"
    else
        range_label="${down} – ${up}°C"
    fi

    is_active=0
    if [ "$LEVEL" = "$lvl" ] || { [[ "$lvl" == *"$LEVEL"* ]] && [ "$LEVEL" != "?" ]; }; then
        is_active=1
    fi

    if [ "$is_active" -eq 1 ]; then
        case "$lvl" in
            0)   row_col="#a6e3a1" ;;
            1|2) row_col="#94e2d5" ;;
            3|4) row_col="#74c7ec" ;;
            5|6) row_col="#f9e2af" ;;
            *)   row_col="#fab387" ;;
        esac
        row_line=$(printf "  <span foreground='%s' weight='bold'>● %-22s %9s  ←</span>" "$row_col" "$lvl_label" "$range_label")
    else
        row_line=$(printf "  <span foreground='#6c7086'>○ %-22s %9s</span>" "$lvl_label" "$range_label")
    fi
    curve_rows+="${row_line}\n"
done < "$CACHE_FILE"

tt="<span foreground='#94e2d5' weight='bold'>󰈐  ThinkFan Cooling Control</span>\n"
tt+="<span foreground='#45475a'>────────────────────────────────────────────</span>\n"
tt+="  Active Mode:    ${m_quiet} <span foreground='#6c7086'>/</span> ${m_auto} <span foreground='#6c7086'>/</span> ${m_max}\n"
tt+="  Fan Speed:      ${rpm_str}  <span foreground='#6c7086'>(EC level: ${LEVEL})</span>\n"
tt+="  Curve Sensor:   <span foreground='#fab387' weight='bold'>${TEMP}°C</span> <span foreground='#6c7086'>(/proc/acpi/ibm/thermal · CPU: ${CPU_TEMP}°C)</span>\n"
tt+="\n<span foreground='#cba6f7' weight='bold'>── Active ThinkFan Profile (${mode}) ──────────</span>\n"
tt+="${curve_rows}"
tt+="<span foreground='#6c7086'><i>Left-click: Fan Mode Menu  ·  Right-click: Cycle Mode</i></span>"

case "$mode" in
    quiet)
        printf '{"text":"󰠝 quiet","class":"quiet","tooltip":"%s"}\n' "$tt"
        ;;
    auto)
        printf '{"text":"󰈐 %s rpm","class":"auto","tooltip":"%s"}\n' "$RPM" "$tt"
        ;;
    max)
        printf '{"text":"󰈐 max","class":"max","tooltip":"%s"}\n' "$tt"
        ;;
    *)
        printf '{"text":"󰈐 ?","class":"unknown","tooltip":"%s"}\n' "$tt"
        ;;
esac
