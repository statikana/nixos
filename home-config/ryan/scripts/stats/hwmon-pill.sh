#!/usr/bin/env bash
# Condensed Hardware Monitor icon pill for Minimal Waybar
# Reuses proc & ThinkPad thermal logic from cpu-status.sh, memory-status.sh, temperature-status.sh
# Keeps numbers off the bar; left-click opens the GTK4 Hardware Flyout.

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
STAT_FILE="$XDG_RUNTIME_DIR/waybar-hwmon-cpu"

# 1. CPU delta from /proc/stat
read -r _ u n s i io irq sirq st _ < /proc/stat
idle=$((i + io))
total=$((u + n + s + idle + irq + sirq + st))

if [ -f "$STAT_FILE" ]; then
    read -r prev_total prev_idle < "$STAT_FILE"
    dt=$((total - prev_total))
    di=$((idle - prev_idle))
    if [ "$dt" -gt 0 ]; then
        cpu=$((100 * (dt - di) / dt))
    else
        cpu=0
    fi
else
    cpu=0
fi
printf "%s %s\n" "$total" "$idle" > "$STAT_FILE"

# 2. RAM usage from /proc/meminfo
read -r mem_total_kb mem_avail_kb < <(
    awk '
        /^MemTotal:/     { mt = $2 }
        /^MemAvailable:/ { ma = $2 }
        END { printf "%d %d", mt, ma }
    ' /proc/meminfo
)
mem_used_kb=$((mem_total_kb - mem_avail_kb))
ram=$((100 * mem_used_kb / (mem_total_kb > 0 ? mem_total_kb : 1)))
used_gib=$(awk -v u="$mem_used_kb" 'BEGIN { printf "%.1f", u / 1048576 }')

# 3. Package thermal & fan RPM from /proc/acpi/ibm
temp=$(awk '{max=$2; for(i=2;i<=NF;i++) if($i>max) max=$i; print max}' /proc/acpi/ibm/thermal 2>/dev/null || echo 40)
[ -z "$temp" ] && temp=40
rpm=$(grep -oP 'speed:\s*\K[0-9]+' /proc/acpi/ibm/fan 2>/dev/null || echo 0)

cls="normal"
if [ "$cpu" -ge 90 ] || [ "$ram" -ge 90 ] || [ "$temp" -ge 82 ] 2>/dev/null; then
    cls="critical"
elif [ "$cpu" -ge 75 ] || [ "$ram" -ge 80 ] || [ "$temp" -ge 70 ] 2>/dev/null; then
    cls="warning"
fi

tt="<span foreground='#cdd6f4' weight='bold'>Hardware Monitor</span>\n"
tt+="<span foreground='#a6adc8'>CPU ${cpu}%  ·  RAM ${ram}% (${used_gib} GiB)  ·  ${temp}°C  ·  ${rpm} RPM</span>\n"
tt+="<span foreground='#6c7086'>Left-click: Flyout  ·  Right-click: Per-Core TUI</span>"

printf '{"text":"󰘚","class":"%s","tooltip":"%s"}\n' "$cls" "$tt"
