#!/usr/bin/env bash
# Stylized Catppuccin Mocha Fan status & Pango tooltip for Waybar (Accent: Teal)
# - Reads /proc/acpi/ibm/thermal max sensor (exact same input thinkfan uses)
# - Parses services.thinkfan.levels from ~/nixos/modules/services.nix ONCE and
#   caches it in $XDG_RUNTIME_DIR/thinkfan-curve.cache (re-parsing only if services.nix changes)

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
SERVICES_NIX="/home/ryan/nixos/modules/services.nix"
CACHE_FILE="$XDG_RUNTIME_DIR/thinkfan-curve.cache"

# Parse thinkfan levels from services.nix only once per boot/session (or if services.nix was edited)
if [ ! -s "$CACHE_FILE" ] || [ "$SERVICES_NIX" -nt "$CACHE_FILE" ]; then
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

mode=$(cat "$XDG_RUNTIME_DIR/fan-mode" 2>/dev/null || echo auto)
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

# Build the curve rows dynamically from the cached services.nix thinkfan levels
curve_rows=""
active_found=0
while IFS='|' read -r lvl down up; do
    [ -z "$lvl" ] && continue

    # Format display label for the fan level
    case "$lvl" in
        0)                  lvl_label="Level 0 (0 RPM Off)" ;;
        1|2|3|4|5|6|7)      lvl_label="Level ${lvl}" ;;
        *disengaged*|*full*) lvl_label="Disengaged (Max)" ;;
        *)                  lvl_label="${lvl}" ;;
    esac

    if [ "$up" -ge 200 ] 2>/dev/null; then
        range_label="${down}°C+"
    else
        range_label="${down} – ${up}°C"
    fi

    # Determine if this bracket is the currently active step
    is_active=0
    if [ "$LEVEL" = "$lvl" ] || { [[ "$lvl" == *"$LEVEL"* ]] && [ "$LEVEL" != "?" ]; }; then
        is_active=1
        active_found=1
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
tt+="\n<span foreground='#cba6f7' weight='bold'>── ThinkFan Curve (modules/services.nix) ───</span>\n"
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
