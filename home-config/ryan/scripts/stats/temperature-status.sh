#!/usr/bin/env bash
# Stylized Catppuccin Mocha Temperature status & Pango tooltip for Waybar
# Reads directly from /proc/acpi/ibm/thermal (the exact tpacpi sensor input used by thinkfan)

ac=$(cat /sys/class/power_supply/AC/online 2>/dev/null || echo 1)

# thinkfan uses /proc/acpi/ibm/thermal and evaluates the highest active sensor against its levels
read -r tpacpi_max tpacpi_cpu tpacpi_zones < <(
    awk '{
        cpu = $2
        max = $2
        zones = ""
        for (i = 2; i <= NF; i++) {
            if ($i > 0) {
                if ($i > max) max = $i
                zones = zones (zones == "" ? "" : " · ") $i "°C"
            }
        }
        printf "%d %d %s\n", max, cpu, zones
    }' /proc/acpi/ibm/thermal 2>/dev/null
)
[ -z "$tpacpi_max" ] && tpacpi_max=40
[ -z "$tpacpi_cpu" ] && tpacpi_cpu="$tpacpi_max"

# Supplementary coretemp & NVMe readings for the tooltip breakdown
core_min=999
core_max=0
core_sum=0
core_cnt=0
nvme_temp="?"

for h in /sys/class/hwmon/hwmon*; do
    name=$(cat "$h/name" 2>/dev/null)
    case "$name" in
        coretemp)
            for ti in "$h"/temp*_input; do
                [ -f "$ti" ] || continue
                lbl=$(cat "${ti%_input}_label" 2>/dev/null || echo "")
                t=$(($(cat "$ti" 2>/dev/null || echo 0) / 1000))
                if [[ "$lbl" == Core* ]]; then
                    [ "$t" -lt "$core_min" ] && core_min="$t"
                    [ "$t" -gt "$core_max" ] && core_max="$t"
                    core_sum=$((core_sum + t))
                    core_cnt=$((core_cnt + 1))
                fi
            done
            ;;
        nvme)
            if [ -f "$h/temp1_input" ]; then
                nvme_temp=$(($(cat "$h/temp1_input" 2>/dev/null || echo 0) / 1000))
            fi
            ;;
    esac
done

if [ "$core_cnt" -gt 0 ]; then
    core_avg=$((core_sum / core_cnt))
else
    core_min="$tpacpi_cpu"
    core_avg="$tpacpi_cpu"
    core_max="$tpacpi_max"
fi

fan_rpm=$(grep -oP 'speed:\s*\K[0-9]+' /proc/acpi/ibm/fan 2>/dev/null || echo "0")
dgpu_state=$(cat /sys/bus/pci/devices/0000:01:00.0/power_state 2>/dev/null || echo "?")

if [ "$tpacpi_max" -ge 80 ] 2>/dev/null; then
    t_col="#f38ba8"
    cls="critical"
    icon="󰸁"
elif [ "$tpacpi_max" -ge 62 ] 2>/dev/null; then
    t_col="#f9e2af"
    cls="warning"
    icon="󰔏"
else
    t_col="#fab387"
    cls="normal"
    icon="󰔏"
fi

# 12-cell thermal bar (25°C to 95°C scale) using the thinkfan sensor reading
bar_len=12
filled=$(( ((tpacpi_max - 25) * bar_len) / 70 ))
[ "$filled" -lt 1 ] && filled=1
[ "$filled" -gt "$bar_len" ] && filled="$bar_len"
empty=$((bar_len - filled))
f_str=""
e_str=""
for ((c=0; c<filled; c++)); do f_str+="━"; done
for ((c=0; c<empty; c++)); do e_str+="─"; done
temp_bar="<span foreground='${t_col}'>${f_str}</span><span foreground='#45475a'>${e_str}</span>"

if [ "$ac" = "0" ]; then
    prochot_str="<span foreground='#a6e3a1' weight='bold'>[65°C BAT]</span> <span foreground='#6c7086'>/ 85°C AC</span>"
else
    prochot_str="<span foreground='#6c7086'>65°C BAT /</span> <span foreground='#74c7ec' weight='bold'>[85°C AC]</span>"
fi

if [ "$dgpu_state" = "D3cold" ]; then
    dgpu_str="<span foreground='#a6e3a1' weight='bold'>D3cold (0W Powered Off)</span>"
else
    dgpu_str="<span foreground='#74c7ec' weight='bold'>${dgpu_state} (Active)</span>"
fi

tt="<span foreground='#fab387' weight='bold'>󰔏  ThinkPad Thermal Sensors (tpacpi)</span>\n"
tt+="<span foreground='#45475a'>────────────────────────────────────────────</span>\n"
tt+="  ThinkFan Input:  ${temp_bar}  <span foreground='${t_col}' weight='bold'>${tpacpi_max}°C</span> <span foreground='#6c7086'>(CPU: ${tpacpi_cpu}°C)</span>\n"
tt+="  Active EC Zones: <span foreground='#cdd6f4'>${tpacpi_zones}</span>\n"
tt+="  Core Die Spread: Min <span foreground='#a6e3a1'>${core_min}°C</span>  ·  Avg <span foreground='#fab387'>${core_avg}°C</span>  ·  Max <span foreground='#f9e2af'>${core_max}°C</span>\n"
tt+="  PROCHOT Ceiling: ${prochot_str}\n"
tt+="\n<span foreground='#cba6f7' weight='bold'>── Component Status ────────────────────────</span>\n"
tt+="  NVMe SSD (Micron 3400):  <span foreground='#94e2d5' weight='bold'>${nvme_temp}°C</span>\n"
tt+="  RTX A2000 dGPU:          ${dgpu_str}\n"
tt+="  ThinkFan Speed:          <span foreground='#94e2d5' weight='bold'>${fan_rpm} RPM</span>\n"
tt+="<span foreground='#6c7086'><i>Left-click: Per-Core Temps &amp; Clocks TUI</i></span>"

printf '{"text":"%s %d°C","class":"%s","tooltip":"%s"}\n' "$icon" "$tpacpi_max" "$cls" "$tt"
