#!/usr/bin/env bash
# Stylized Catppuccin Mocha CPU status & Pango tooltip for Waybar
# Computes exact CPU % from /proc/stat delta across intervals (zero sleep delay)

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
STAT_FILE="$XDG_RUNTIME_DIR/waybar-cpu-stat"

read -r _ u n s i io irq sirq st _ < /proc/stat
idle=$((i + io))
total=$((u + n + s + idle + irq + sirq + st))

if [ -f "$STAT_FILE" ]; then
    read -r prev_total prev_idle < "$STAT_FILE"
    dt=$((total - prev_total))
    di=$((idle - prev_idle))
    if [ "$dt" -gt 0 ]; then
        usage=$((100 * (dt - di) / dt))
    else
        usage=0
    fi
else
    usage=0
fi
printf "%s %s\n" "$total" "$idle" > "$STAT_FILE"

# Load average
read -r l1 l5 l15 _ < /proc/loadavg

# Frequencies (in GHz) across online cores
read -r min_ghz avg_ghz max_ghz < <(
    awk '{
        val = $1 / 1000000
        if (NR == 1 || val < min) min = val
        if (val > max) max = val
        sum += val
        n++
    } END {
        if (n > 0) printf "%.2f %.2f %.2f", min, sum/n, max
        else print "0.00 0.00 0.00"
    }' /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq 2>/dev/null
)

no_turbo=$(cat /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || echo 0)
epp=$(cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference 2>/dev/null || echo "unknown")
pl1_w=$(($(cat /sys/class/powercap/intel-rapl:0/constraint_0_power_limit_uw 2>/dev/null || echo 0) / 1000000))
pl2_w=$(($(cat /sys/class/powercap/intel-rapl:0/constraint_1_power_limit_uw 2>/dev/null || echo 0) / 1000000))

# Read thermal sensor from /proc/acpi/ibm/thermal (same tpacpi input used by thinkfan)
pkg_temp=$(awk '{max=$2; for(i=2;i<=NF;i++) if($i>max) max=$i; print max}' /proc/acpi/ibm/thermal 2>/dev/null || echo "?")

# Build a 12-cell Pango progress bar
bar_len=12
filled=$(( (usage * bar_len + 50) / 100 ))
[ "$filled" -gt "$bar_len" ] && filled="$bar_len"
empty=$((bar_len - filled))

if [ "$usage" -ge 80 ]; then
    u_col="#f38ba8"
    cls="critical"
elif [ "$usage" -ge 50 ]; then
    u_col="#f9e2af"
    cls="warning"
else
    u_col="#a6e3a1"
    cls="normal"
fi

f_str=""
e_str=""
for ((c=0; c<filled; c++)); do f_str+="━"; done
for ((c=0; c<empty; c++)); do e_str+="─"; done
pango_bar="<span foreground='${u_col}'>${f_str}</span><span foreground='#45475a'>${e_str}</span>"

if [ "$no_turbo" = "1" ]; then
    turbo_pill="<span foreground='#a6e3a1' weight='bold'>[Off · BAT]</span> <span foreground='#6c7086'>/ On</span>"
else
    turbo_pill="<span foreground='#6c7086'>Off /</span> <span foreground='#74c7ec' weight='bold'>[On · AC]</span>"
fi

# Top 4 CPU processes (pcpu first so process names with spaces like "Isolated Web Co" parse cleanly)
top_procs=$(ps -eo pcpu=,comm= --sort=-pcpu 2>/dev/null | head -n 4 | awk '{
    cpu = $1; $1 = ""; sub(/^[ \t]+/, "", $0);
    name = substr($0, 1, 18);
    gsub(/&/, "&amp;", name); gsub(/</, "&lt;", name); gsub(/>/, "&gt;", name); gsub(/"/, "", name);
    printf "  <span foreground=\x27#cdd6f4\x27>%-18s</span> <span foreground=\x27#74c7ec\x27 weight=\x27bold\x27>%5.1f%%</span>\\n", name, cpu
}')

tt="<span foreground='#74c7ec' weight='bold'>󰘚  Intel Core i7-12700H</span>  <span foreground='#6c7086'>(6P+8E · 20 Threads)</span>\n"
tt+="<span foreground='#45475a'>────────────────────────────────────────────</span>\n"
tt+="  Utilization:   ${pango_bar}  <span foreground='${u_col}' weight='bold'>${usage}%</span>\n"
tt+="  Load Average:  <span foreground='#cdd6f4'>${l1}</span> <span foreground='#6c7086'>(1m)</span>  ·  <span foreground='#cdd6f4'>${l5}</span> <span foreground='#6c7086'>(5m)</span>  ·  <span foreground='#cdd6f4'>${l15}</span> <span foreground='#6c7086'>(15m)</span>\n"
tt+="  Clock Speed:   <span foreground='#74c7ec' weight='bold'>${avg_ghz} GHz</span> <span foreground='#6c7086'>avg  (${min_ghz}–${max_ghz} GHz)</span>\n"
tt+="  Turbo Boost:   ${turbo_pill}\n"
tt+="  Power &amp; Temp:  <span foreground='#a6e3a1' weight='bold'>${pkg_temp}°C</span>  <span foreground='#6c7086'>·  PL1/PL2: ${pl1_w}W / ${pl2_w}W  ·  EPP: ${epp}</span>\n"
tt+="\n<span foreground='#cba6f7' weight='bold'>── Top Active Processes ────────────────────</span>\n"
tt+="${top_procs}"
tt+="<span foreground='#6c7086'><i>Left-click: Per-Core Temps &amp; Clocks TUI  ·  Right-click: btop</i></span>"

printf '{"text":"󰘚 %2d%%","class":"%s","tooltip":"%s"}\n' "$usage" "$cls" "$tt"
