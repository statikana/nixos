#!/usr/bin/env bash
# On-demand Hardware, Per-Core Temperatures, Clocks & Memory TUI (Catppuccin Mocha)
# Opened when left-clicking CPU, Memory, or Temperature in Waybar.

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
SCRIPTS_DIR="/home/ryan/nixos/home-config/ryan/scripts"

RST=$'\033[0m'
EL=$'\033[K'
BOLD=$'\033[1m'
DIM=$'\033[38;2;108;112;134m'      # overlay0 #6c7086
SUB=$'\033[38;2;166;173;200m'      # subtext0 #a6adc8
TXT=$'\033[38;2;205;214;244m'      # text     #cdd6f4
BORDER=$'\033[38;2;69;71;90m'      # surface1 #45475a
GREEN=$'\033[1;38;2;166;227;161m'  # green    #a6e3a1
BLUE=$'\033[1;38;2;116;199;236m'   # sapphire #74c7ec
PEACH=$'\033[1;38;2;250;179;135m'  # peach    #fab387
MAUVE=$'\033[1;38;2;203;166;247m'  # mauve    #cba6f7
TEAL=$'\033[1;38;2;148;226;213m'   # teal     #94e2d5
YELLOW=$'\033[1;38;2;249;226;175m' # yellow   #f9e2af
RED=$'\033[1;38;2;243;139;168m'    # red      #f38ba8
BG_SURF=$'\033[1;38;2;205;214;244;48;2;49;50;68m'

make_ansi_bar() {
    local pct="$1" len="$2" col="$3"
    local fill=$(( (pct * len + 50) / 100 ))
    [ "$fill" -lt 0 ] && fill=0
    [ "$fill" -gt "$len" ] && fill="$len"
    local emp=$((len - fill))
    local fs="" es="" i
    for ((i=0; i<fill; i++)); do fs+="━"; done
    for ((i=0; i<emp; i++)); do es+="─"; done
    printf "%s%s%s%s%s" "$col" "$fs" "$BORDER" "$es" "$RST"
}

temp_color() {
    local t="$1"
    if [ "${t:-0}" -ge 78 ] 2>/dev/null; then
        printf "%s" "$RED"
    elif [ "${t:-0}" -ge 58 ] 2>/dev/null; then
        printf "%s" "$YELLOW"
    else
        printf "%s" "$GREEN"
    fi
}

read -r _ u1 n1 s1 i1 io1 irq1 sirq1 st1 _ < /proc/stat
prev_idle=$((i1 + io1))
prev_total=$((u1 + n1 + s1 + prev_idle + irq1 + sirq1 + st1))

tput civis 2>/dev/null || true
trap 'tput cnorm 2>/dev/null || true; clear' EXIT INT TERM
clear

while true; do
    printf '\033[H'

    # 1. CPU Utilization delta
    read -r _ u2 n2 s2 i2 io2 irq2 sirq2 st2 _ < /proc/stat
    cur_idle=$((i2 + io2))
    cur_total=$((u2 + n2 + s2 + cur_idle + irq2 + sirq2 + st2))
    dt=$((cur_total - prev_total))
    di=$((cur_idle - prev_idle))
    if [ "$dt" -gt 0 ]; then
        cpu_pct=$((100 * (dt - di) / dt))
    else
        cpu_pct=0
    fi
    prev_total="$cur_total"
    prev_idle="$cur_idle"

    read -r l1 l5 l15 _ < /proc/loadavg
    read -r min_ghz avg_ghz max_ghz < <(
        awk '{
            val = $1 / 1000000
            if (NR == 1 || val < min) min = val
            if (val > max) max = val
            sum += val; n++
        } END {
            if (n > 0) printf "%.2f %.2f %.2f", min, sum/n, max
            else print "0.00 0.00 0.00"
        }' /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq 2>/dev/null
    )

    pl1_w=$(($(cat /sys/class/powercap/intel-rapl:0/constraint_0_power_limit_uw 2>/dev/null || echo 0) / 1000000))
    pl2_w=$(($(cat /sys/class/powercap/intel-rapl:0/constraint_1_power_limit_uw 2>/dev/null || echo 0) / 1000000))
    fan_mode=$(cat "$XDG_RUNTIME_DIR/fan-mode" 2>/dev/null || echo auto)
    fan_rpm=$(grep -oP 'speed:\s*\K[0-9]+' /proc/acpi/ibm/fan 2>/dev/null || echo 0)
    dgpu_state=$(cat /sys/bus/pci/devices/0000:01:00.0/power_state 2>/dev/null || echo "?")

    # 2. Read ThinkFan sensor (/proc/acpi/ibm/thermal) + coretemp & nvme sensors
    tpacpi_temp=$(awk '{max=$2; for(i=2;i<=NF;i++) if($i>max) max=$i; print max}' /proc/acpi/ibm/thermal 2>/dev/null || echo 40)
    pkg_temp="$tpacpi_temp"
    nvme_temp="?"
    core_labels=()
    core_temps=()
    for h in /sys/class/hwmon/hwmon*; do
        hname=$(cat "$h/name" 2>/dev/null)
        case "$hname" in
            coretemp)
                for ti in "$h"/temp*_input; do
                    [ -f "$ti" ] || continue
                    lbl=$(cat "${ti%_input}_label" 2>/dev/null || echo "")
                    t=$(($(cat "$ti" 2>/dev/null || echo 0) / 1000))
                    if [[ "$lbl" == Core* ]]; then
                        core_labels+=("$lbl")
                        core_temps+=("$t")
                    fi
                done
                ;;
            nvme)
                [ -f "$h/temp1_input" ] && nvme_temp=$(($(cat "$h/temp1_input" 2>/dev/null || echo 0) / 1000))
                ;;
        esac
    done

    # 3. Memory & Swap
    read -r mem_total_kb mem_avail_kb mem_buf_kb mem_cached_kb mem_srec_kb swap_total_kb swap_free_kb < <(
        awk '
            /^MemTotal:/     { mt = $2 }
            /^MemAvailable:/ { ma = $2 }
            /^Buffers:/      { mb = $2 }
            /^Cached:/       { mc = $2 }
            /^SReclaimable:/ { ms = $2 }
            /^SwapTotal:/    { st = $2 }
            /^SwapFree:/     { sf = $2 }
            END { printf "%d %d %d %d %d %d %d", mt, ma, mb, mc, ms, st, sf }
        ' /proc/meminfo
    )
    mem_used_kb=$((mem_total_kb - mem_avail_kb))
    mem_cache_kb=$((mem_buf_kb + mem_cached_kb + mem_srec_kb))
    swap_used_kb=$((swap_total_kb - swap_free_kb))
    mem_pct=$((100 * mem_used_kb / (mem_total_kb > 0 ? mem_total_kb : 1)))
    swap_pct=$((swap_total_kb > 0 ? (100 * swap_used_kb / swap_total_kb) : 0))
    read -r used_gib total_gib avail_gib cache_gib swap_used_gib swap_total_gib < <(
        awk -v u="$mem_used_kb" -v t="$mem_total_kb" -v a="$mem_avail_kb" -v c="$mem_cache_kb" -v su="$swap_used_kb" -v st="$swap_total_kb" '
        BEGIN {
            printf "%.1f %.1f %.1f %.1f %.1f %.1f",
                u/1048576, t/1048576, a/1048576, c/1048576, su/1048576, st/1048576
        }'
    )

    cpu_col="$GREEN"
    [ "$cpu_pct" -ge 50 ] && cpu_col="$YELLOW"
    [ "$cpu_pct" -ge 80 ] && cpu_col="$RED"
    pkg_col=$(temp_color "$pkg_temp")

    printf "${BORDER}╭──────────────────────────────────────────────────────────────────────────────╮${RST}${EL}\n"
    printf "${BORDER}│${RST}  ${BOLD}${TXT}󰘚  ThinkPad P1 Gen 5 — CPU, Per-Core Thermals & Memory Monitor${RST}              ${BORDER}│${RST}${EL}\n"
    printf "${BORDER}╰──────────────────────────────────────────────────────────────────────────────╯${RST}${EL}\n"

    printf "${EL}\n ${BLUE}󰘚  CPU & Package Overview (i7-12700H · 6P + 8E · 20 Threads)${RST}${EL}\n"
    printf " ${BORDER}──────────────────────────────────────────────────────────────────────────────${RST}${EL}\n"
    printf "  ${TXT}%-20s${RST} %s  ${cpu_col}%3d%%${RST}     ${SUB}Load Avg:${RST} ${TXT}%s · %s · %s${RST}${EL}\n" \
        "Total Utilization" "$(make_ansi_bar "$cpu_pct" 18 "$cpu_col")" "$cpu_pct" "$l1" "$l5" "$l15"
    printf "  ${TXT}%-20s${RST} ${BLUE}%s GHz${RST} avg  ${DIM}(%s – %s GHz)${RST}   ${SUB}RAPL PL1/2:${RST} ${TXT}%sW / %sW${RST}${EL}\n" \
        "Clock Frequency" "$avg_ghz" "$min_ghz" "$max_ghz" "$pl1_w" "$pl2_w"
    printf "  ${TXT}%-20s${RST} %s  ${pkg_col}%3s°C${RST}    ${SUB}ThinkFan:${RST} ${TEAL}%s RPM${RST} ${DIM}(%s)${RST}${EL}\n" \
        "Package Temperature" "$(make_ansi_bar $(( (pkg_temp - 25) * 100 / 70 )) 18 "$pkg_col")" "$pkg_temp" "$fan_rpm" "$fan_mode"

    printf "${EL}\n ${PEACH}󰔏  Per-Core Temperatures (coretemp) & Chassis Sensors${RST}${EL}\n"
    printf " ${BORDER}──────────────────────────────────────────────────────────────────────────────${RST}${EL}\n"
    num_cores=${#core_labels[@]}
    for ((idx=0; idx<num_cores; idx+=2)); do
        lbl1="${core_labels[$idx]}"
        t1="${core_temps[$idx]}"
        c1=$(temp_color "$t1")
        b1=$(make_ansi_bar $(( (t1 - 25) * 100 / 70 )) 10 "$c1")
        col1=$(printf "  ${SUB}%-9s${RST} %s ${c1}%2d°C${RST}" "$lbl1" "$b1" "$t1")

        if [ $((idx + 1)) -lt "$num_cores" ]; then
            lbl2="${core_labels[$((idx + 1))]}"
            t2="${core_temps[$((idx + 1))]}"
            c2=$(temp_color "$t2")
            b2=$(make_ansi_bar $(( (t2 - 25) * 100 / 70 )) 10 "$c2")
            col2=$(printf "        ${SUB}%-9s${RST} %s ${c2}%2d°C${RST}" "$lbl2" "$b2" "$t2")
        else
            col2=""
        fi
        printf "%s%s${EL}\n" "$col1" "$col2"
    done
    printf "  ${SUB}NVMe SSD:${RST} ${TEAL}%s°C${RST}               ${SUB}RTX A2000 dGPU:${RST} ${GREEN}%s${RST}${EL}\n" "$nvme_temp" "$dgpu_state"

    mem_col="$GREEN"
    [ "$mem_pct" -ge 65 ] && mem_col="$YELLOW"
    [ "$mem_pct" -ge 85 ] && mem_col="$RED"

    printf "${EL}\n ${MAUVE}󰍛  Memory & Swap Space${RST}${EL}\n"
    printf " ${BORDER}──────────────────────────────────────────────────────────────────────────────${RST}${EL}\n"
    printf "  ${TXT}%-20s${RST} %s  ${mem_col}%s / %s GiB (%d%%)${RST}${EL}\n" \
        "RAM In Use" "$(make_ansi_bar "$mem_pct" 18 "$mem_col")" "$used_gib" "$total_gib" "$mem_pct"
    printf "  ${TXT}%-20s${RST} ${GREEN}%s GiB${RST} available   ${DIM}·${RST}   ${BLUE}%s GiB${RST} page cache / buffers${EL}\n" \
        "Memory Headroom" "$avail_gib" "$cache_gib"
    printf "  ${TXT}%-20s${RST} %s  ${TEAL}%s / %s GiB (%d%%)${RST}${EL}\n" \
        "Swap Partition" "$(make_ansi_bar "$swap_pct" 18 "$TEAL")" "$swap_used_gib" "$swap_total_gib" "$swap_pct"

    printf "${EL}\n ${YELLOW}󰓅  Top Active Processes (CPU vs Memory)${RST}${EL}\n"
    printf " ${BORDER}──────────────────────────────────────────────────────────────────────────────${RST}${EL}\n"
    mapfile -t top_c < <(ps -eo pcpu=,comm= --sort=-pcpu 2>/dev/null | head -n 4 | awk '{c=$1; $1=""; sub(/^[ \t]+/,"",$0); printf "%-18s %5.1f%%", substr($0,1,18), c}')
    mapfile -t top_m < <(ps -eo rss=,comm= --sort=-rss 2>/dev/null | head -n 4 | awk '{r=$1; $1=""; sub(/^[ \t]+/,"",$0); printf "%-18s %5.2fG", substr($0,1,18), r/1048576}')
    for ((r=0; r<4; r++)); do
        printf "  ${TXT}%-26s${RST}          ${TXT}%-26s${RST}${EL}\n" "${top_c[$r]:-}" "${top_m[$r]:-}"
    done

    fan_pad=$(printf "%-5s" "$fan_mode")
    printf "${EL}\n${BORDER}╭──────────────────────────────────────────────────────────────────────────────╮${RST}${EL}\n"
    printf "${BORDER}│${RST}  ${BG_SURF} [b] ${RST} Open btop   ${BG_SURF} [p] ${RST} Battery TUI   ${BG_SURF} [f] ${RST} Fan: ${BOLD}${TXT}${fan_pad}${RST}   ${BG_SURF} [q] ${RST} Close TUI    ${BORDER}│${RST}${EL}\n"
    printf "${BORDER}╰──────────────────────────────────────────────────────────────────────────────╯${RST}${EL}\n"

    if read -rsn1 -t 1.5 key; then
        case "$key" in
            b|B) tput cnorm 2>/dev/null || true; exec btop ;;
            p|P) exec "$SCRIPTS_DIR/power/battery-changes.sh" --interactive ;;
            f|F) "$SCRIPTS_DIR/fan/fan-toggle.sh" >/dev/null 2>&1 ;;
            q|Q|$'\e'|"") break ;;
        esac
    fi
done
