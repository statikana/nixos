#!/usr/bin/env bash
# Unified Battery & AC Power Optimizations TUI + Waybar Tooltip
# - Default (no args): outputs Waybar JSON with Pango-highlighted BAT / AC states
# - `--interactive`: runs a live-updating Catppuccin Mocha TUI in WezTerm

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && [ -d "$XDG_RUNTIME_DIR/hypr" ]; then
    export HYPRLAND_INSTANCE_SIGNATURE
    HYPRLAND_INSTANCE_SIGNATURE=$(ls -1 "$XDG_RUNTIME_DIR/hypr" 2>/dev/null | head -n 1)
fi

SCRIPTS_DIR="/home/ryan/nixos/home-config/ryan/scripts"

collect_state() {
    ac=$(cat /sys/class/power_supply/AC/online 2>/dev/null || echo 1)
    bat_cap=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo "?")
    bat_status=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo "Unknown")
    power_uw=$(cat /sys/class/power_supply/BAT0/power_now 2>/dev/null || echo 0)
    power_w=$(awk "BEGIN { printf \"%.1f\", $power_uw / 1000000 }" 2>/dev/null || echo "0.0")

    mode=$(cat "$XDG_RUNTIME_DIR/power-mode" 2>/dev/null || echo balanced)
    fan_mode=$(cat "$XDG_RUNTIME_DIR/fan-mode" 2>/dev/null || echo auto)
    profile=$(cat /sys/firmware/acpi/platform_profile 2>/dev/null || echo unknown)
    epp=$(cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference 2>/dev/null || echo unknown)
    no_turbo=$(cat /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || echo 0)
    hwp_boost=$(cat /sys/devices/system/cpu/intel_pstate/hwp_dynamic_boost 2>/dev/null || echo 1)
    aspm=$(sed -n 's/.*\[\(.*\)\].*/\1/p' /sys/module/pcie_aspm/parameters/policy 2>/dev/null || echo unknown)

    pl1_uw=$(cat /sys/class/powercap/intel-rapl:0/constraint_0_power_limit_uw 2>/dev/null || echo 0)
    pl2_uw=$(cat /sys/class/powercap/intel-rapl:0/constraint_1_power_limit_uw 2>/dev/null || echo 0)
    pl1_w=$((pl1_uw / 1000000))
    pl2_w=$((pl2_uw / 1000000))

    igpu_max=$(cat /sys/class/drm/card1/gt/gt0/rps_max_freq_mhz 2>/dev/null || echo "1400")
    dgpu_state=$(cat /sys/bus/pci/devices/0000:01:00.0/power_state 2>/dev/null || echo "?")
    fan_rpm=$(grep -oP 'speed:\s*\K[0-9]+' /proc/acpi/ibm/fan 2>/dev/null || echo "0")
    cpu_temp=$(awk '{max=$2; for(i=2;i<=NF;i++) if($i>max) max=$i; print max}' /proc/acpi/ibm/thermal 2>/dev/null || echo "?")
    fan_zero_up=$(awk -F'|' '$1=="0" {print $3; exit}' "$XDG_RUNTIME_DIR/thinkfan-curve.cache" 2>/dev/null)
    [ -z "$fan_zero_up" ] && fan_zero_up="48"

    dirty_cs=$(cat /proc/sys/vm/dirty_writeback_centisecs 2>/dev/null || echo "1500")
    dirty_s=$((dirty_cs / 100))

    wifi_ps=$(iw dev wlp0s20f3 get power_save 2>/dev/null | awk '{print $3}')
    if [ -z "$wifi_ps" ]; then
        wifi_mod=$(cat /sys/module/iwlwifi/parameters/power_save 2>/dev/null || echo "N")
        [ "$wifi_mod" = "Y" ] || [ "$wifi_mod" = "1" ] && wifi_ps="on" || wifi_ps="off"
    fi

    snd_ps=$(cat /sys/module/snd_hda_intel/parameters/power_save 2>/dev/null || echo "0")

    if systemctl is-active --quiet docker.service 2>/dev/null; then
        docker_state="running"
    else
        docker_state="socket-idle"
    fi

    if rfkill list bluetooth 2>/dev/null | grep -q "Soft blocked: yes"; then
        bt_state="off"
    else
        bt_state="on"
    fi

    # Hyprland live query (falls back to AC state if socket unavailable)
    edp_hz=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.name=="eDP-1") | (.refreshRate | round | tostring)' 2>/dev/null)
    if [ -z "$edp_hz" ] || [ "$edp_hz" = "null" ]; then
        [ "$ac" = "0" ] && edp_hz="60" || edp_hz="165"
    fi

    blur_on=$(hyprctl getoption decoration:blur:enabled -j 2>/dev/null | jq -r '.int' 2>/dev/null)
    if [ -z "$blur_on" ] || [ "$blur_on" = "null" ]; then
        [ "$ac" = "0" ] && blur_on="0" || blur_on="1"
    fi
}

# ============================================================================
# INTERACTIVE WEZTERM TUI (--interactive | --dump-once)
# ============================================================================
if [ "${1:-}" = "--interactive" ] || [ "${1:-}" = "--dump-once" ]; then
    # Catppuccin Mocha truecolor ANSI codes
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

    BG_GREEN=$'\033[1;38;2;17;17;27;48;2;166;227;161m'
    BG_BLUE=$'\033[1;38;2;17;17;27;48;2;116;199;236m'
    BG_PEACH=$'\033[1;38;2;17;17;27;48;2;250;179;135m'
    BG_SURF=$'\033[1;38;2;205;214;244;48;2;49;50;68m'

    # Format a 2-way (BAT / AC) comparison where $1=active_side ("bat" or "ac"), $2=bat_text, $3=ac_text
    fmt_pair() {
        local active="$1" bat_txt="$2" ac_txt="$3"
        if [ "$active" = "bat" ]; then
            printf "%s ● %s %s %s/%s %s%s%s" "$BG_GREEN" "$bat_txt" "$RST" "$DIM" "$RST" "$DIM" "$ac_txt" "$RST"
        else
            printf "%s%s%s %s/%s %s ● %s %s" "$DIM" "$bat_txt" "$RST" "$DIM" "$RST" "$BG_BLUE" "$ac_txt" "$RST"
        fi
    }

    # Format a 3-way (Saver / Balanced / Perf) comparison where $1=1|2|3
    fmt_triple() {
        local idx="$1" t1="$2" t2="$3" t3="$4"
        local o1="${DIM}${t1}${RST}" o2="${DIM}${t2}${RST}" o3="${DIM}${t3}${RST}"
        case "$idx" in
            1) o1="${BG_GREEN} ● ${t1} ${RST}" ;;
            2) o2="${BG_BLUE} ● ${t2} ${RST}" ;;
            3) o3="${BG_PEACH} ● ${t3} ${RST}" ;;
        esac
        printf "%s %s/%s %s %s/%s %s" "$o1" "$DIM" "$RST" "$o2" "$DIM" "$RST" "$o3"
    }

    if [ "${1:-}" = "--interactive" ]; then
        printf '\033[?1049h\033[2J\033[H'
        tput civis 2>/dev/null || true
        trap 'tput cnorm 2>/dev/null || true; printf "\033[?1049l"' EXIT INT TERM
    fi

    render_frame() {
        if [ "$ac" = "0" ]; then
            src_txt=$(printf "%-30s" " ● ON BATTERY (DISCHARGING)")
            src_badge="${BG_GREEN}${src_txt}${RST}"
            draw_plain=$(printf "-%sW (%s%%)" "$power_w" "$bat_cap")
            draw_pad=$(printf "%-22s" "$draw_plain")
            draw_str="${GREEN}${draw_pad}${RST}"
        else
            src_txt=$(printf "%-30s" " ● ON AC POWER (${bat_status^^})")
            src_badge="${BG_BLUE}${src_txt}${RST}"
            draw_plain=$(printf "%sW (%s%%)" "$power_w" "$bat_cap")
            draw_pad=$(printf "%-22s" "$draw_plain")
            draw_str="${BLUE}${draw_pad}${RST}"
        fi

        printf "${BORDER}╭──────────────────────────────────────────────────────────────────────────────╮${RST}${EL}\n"
        printf "${BORDER}│${RST}  ${BOLD}${TXT}󰌪  ThinkPad P1 Gen 5 — Power & Battery Optimizations${RST}                        ${BORDER}│${RST}${EL}\n"
        printf "${BORDER}├──────────────────────────────────────────────────────────────────────────────┤${RST}${EL}\n"
        printf "${BORDER}│${RST}  %s   ${SUB}Battery:${RST} %s            ${BORDER}│${RST}${EL}\n" "$src_badge" "$draw_str"
        printf "${BORDER}│${RST}  ${SUB}Active Pill:${RST}  ${BG_GREEN} ● Battery State ${RST}  ${DIM}/${RST}  ${BG_BLUE} ● AC State ${RST}  ${DIM}/${RST}  ${BG_PEACH} ● Performance ${RST}        ${BORDER}│${RST}${EL}\n"
        printf "${BORDER}╰──────────────────────────────────────────────────────────────────────────────╯${RST}${EL}\n"

        printf " ${MAUVE}󰍹  Display & Compositor (Hyprland + Intel Iris Xe)${RST} ${BORDER}───────────────────────────${RST}${EL}\n"
        printf "  ${TXT}%-28s${RST} %s${EL}\n" "eDP-1 Refresh Rate" \
            "$(fmt_pair "$([ "$edp_hz" -le 65 ] 2>/dev/null && echo bat || echo ac)" "60 Hz" "165 Hz")"
        printf "  ${TXT}%-28s${RST} %s${EL}\n" "Window Blur & Drop Shadows" \
            "$(fmt_pair "$([ "$blur_on" = "0" ] && echo bat || echo ac)" "Disabled" "Enabled")"
        printf "  ${TXT}%-28s${RST} %s${EL}\n" "Unfocused Window Opacity" \
            "$(fmt_pair "$([ "$blur_on" = "0" ] && echo bat || echo ac)" "1.00 (Opaque)" "0.95 (Glass)")"
        printf "  ${TXT}%-28s${RST} %s${EL}\n" "Workspace Animations" \
            "$(fmt_pair "$([ "$blur_on" = "0" ] && echo bat || echo ac)" "Disabled" "Enabled")"
        printf "  ${TXT}%-28s${RST} ${TEAL}● Always On${RST}  ${SUB}(i915 HW Cursor Plane + Direct Scanout)${RST}${EL}\n" "Hardware Cursor & Scanout"

        printf " ${PEACH}󰘚  CPU, Thermals & Fan Control (i7-12700H)${RST} ${BORDER}───────────────────────────────────${RST}${EL}\n"
        prof_idx=2
        [ "$profile" = "low-power" ] && prof_idx=1
        [ "$profile" = "performance" ] && prof_idx=3
        printf "  ${TXT}%-28s${RST} %s${EL}\n" "ACPI Platform Profile" \
            "$(fmt_triple "$prof_idx" "low-power" "balanced" "performance")"

        rapl_idx=2
        [ "$pl1_w" -le 25 ] && rapl_idx=1
        [ "$pl1_w" -ge 40 ] && rapl_idx=3
        printf "  ${TXT}%-28s${RST} %s  ${SUB}(now: ${pl1_w}W/${pl2_w}W)${RST}${EL}\n" "RAPL Package Limits (PL1/2)" \
            "$(fmt_triple "$rapl_idx" "20W / 35W" "35W / 65W" "45W / 115W")"

        printf "  ${TXT}%-28s${RST} %s${EL}\n" "CPU Turbo Boost" \
            "$(fmt_pair "$([ "$no_turbo" = "1" ] && echo bat || echo ac)" "Off (≤2.3 GHz)" "On (≤4.7 GHz)")"
        printf "  ${TXT}%-28s${RST} %s${EL}\n" "HWP Dynamic Boost" \
            "$(fmt_pair "$([ "$hwp_boost" = "0" ] && echo bat || echo ac)" "Disabled" "Enabled")"
        printf "  ${TXT}%-28s${RST} %s${EL}\n" "Energy Perf Policy (EPP)" \
            "$(fmt_pair "$([ "$epp" = "power" ] && echo bat || echo ac)" "power" "$epp")"
        printf "  ${TXT}%-28s${RST} %s  ${SUB}(CPU: ${cpu_temp}°C)${RST}${EL}\n" "PROCHOT Thermal Target" \
            "$(fmt_pair "$([ "$ac" = "0" ] && echo bat || echo ac)" "65°C Ceiling" "85°C Ceiling")"
        printf "  ${TXT}%-28s${RST} %s  ${SUB}(mode: ${fan_mode})${RST}${EL}\n" "ThinkFan Acoustic Curve" \
            "$(fmt_pair "$([ "${fan_rpm:-0}" -eq 0 ] 2>/dev/null && echo bat || echo ac)" "0 RPM (<${fan_zero_up}°C)" "Active (${fan_rpm} RPM)")"

        printf " ${YELLOW}󰢮  Graphics & Media Engines (Iris Xe + RTX A2000)${RST} ${BORDER}────────────────────────────${RST}${EL}\n"
        printf "  ${TXT}%-28s${RST} %s  ${SUB}(+ FBC & GuC=3)${RST}${EL}\n" "Intel Iris Xe Max Clock" \
            "$(fmt_pair "$([ "${igpu_max:-1400}" -le 700 ] 2>/dev/null && echo bat || echo ac)" "600 MHz Cap" "1400 MHz Boost")"
        printf "  ${TXT}%-28s${RST} %s  ${SUB}(VRAM Off + S0ix=1)${RST}${EL}\n" "NVIDIA RTX A2000 State" \
            "$(fmt_pair "$([ "$dgpu_state" = "D3cold" ] && echo bat || echo ac)" "D3cold (0W Off)" "${dgpu_state} (Active)")"
        printf "  ${TXT}%-28s${RST} ${TEAL}● Always On${RST}  ${SUB}(Mesa EGL + Intel Vulkan + iHD VA-API)${RST}${EL}\n" "dGPU Isolation & VA-API"

        printf " ${BLUE}󰋊  Storage, Radios & Background Daemons${RST} ${BORDER}──────────────────────────────────────${RST}${EL}\n"
        printf "  ${TXT}%-28s${RST} %s${EL}\n" "PCIe ASPM Link Policy" \
            "$(fmt_pair "$([ "$aspm" = "powersupersave" ] && echo bat || echo ac)" "powersupersave" "$aspm")"
        printf "  ${TXT}%-28s${RST} %s  ${SUB}(+ ext4 noatime)${RST}${EL}\n" "NVMe Dirty Writeback" \
            "$(fmt_pair "$([ "${dirty_s:-15}" -ge 30 ] 2>/dev/null && echo bat || echo ac)" "60s Batching" "15s Batching")"
        printf "  ${TXT}%-28s${RST} %s  ${SUB}(iwlmvm scheme 3)${RST}${EL}\n" "Intel CNVi Wi-Fi Power Save" \
            "$(fmt_pair "$([ "$wifi_ps" = "on" ] && echo bat || echo ac)" "On (Low-Power)" "Off (Low-Latency)")"
        printf "  ${TXT}%-28s${RST} ${TEAL}● Always On${RST}  ${SUB}(HDA ${snd_ps}s sleep · 01:00.1 & libcamera off)${RST}${EL}\n" "Audio & Webcam Isolation"
        printf "  ${TXT}%-28s${RST} ${TEAL}● On-Demand${RST}  ${SUB}(Docker: ${docker_state} · BT: ${bt_state} · BAT 75–85%%)${RST}${EL}\n" "Daemons & Charge Cap"

        mode_pad=$(printf "%-11s" "$mode")
        fan_pad=$(printf "%-5s" "$fan_mode")
        printf "${BORDER}╭──────────────────────────────────────────────────────────────────────────────╮${RST}${EL}\n"
        printf "${BORDER}│${RST}  ${BG_SURF} [p] ${RST} Power: ${BOLD}${TXT}${mode_pad}${RST} ${BG_SURF} [f] ${RST} Fan: ${BOLD}${TXT}${fan_pad}${RST} ${BG_SURF} [b] ${RST} Toggle BT  ${BG_SURF} [q] ${RST} Close TUI  ${BORDER}│${RST}${EL}\n"
        printf "${BORDER}╰──────────────────────────────────────────────────────────────────────────────╯${RST}${EL}"
    }

    while true; do
        collect_state

        if [ "${1:-}" = "--dump-once" ]; then
            render_frame
            printf '\n'
            break
        fi

        term_rows=$(tput lines 2>/dev/null || echo 40)
        [ "${term_rows:-0}" -lt 10 ] 2>/dev/null && term_rows=40
        frame=$(render_frame | head -n "$term_rows")
        printf '\033[H%s\033[J' "$frame"

        if read -rsn1 -t 1.5 key; then
            case "$key" in
                p|P) "$SCRIPTS_DIR/power/power-toggle.sh" >/dev/null 2>&1 ;;
                f|F) "$SCRIPTS_DIR/fan/fan-toggle.sh" >/dev/null 2>&1 ;;
                b|B) rfkill toggle bluetooth >/dev/null 2>&1 ;;
                q|Q|$'\e'|"") break ;;
            esac
        fi
    done
    exit 0
fi

# ============================================================================
# WAYBAR JSON + PANGO TOOLTIP (default)
# ============================================================================
collect_state

# Pango helper: highlights active option in green (BAT) or sapphire (AC) and dims the inactive side
pango_pair() {
    local active="$1" bat_txt="$2" ac_txt="$3"
    if [ "$active" = "bat" ]; then
        printf "<span foreground='#a6e3a1' weight='bold'>[%s]</span> <span foreground='#6c7086'>/ %s</span>" "$bat_txt" "$ac_txt"
    else
        printf "<span foreground='#6c7086'>%s /</span> <span foreground='#74c7ec' weight='bold'>[%s]</span>" "$bat_txt" "$ac_txt"
    fi
}

pango_triple() {
    local idx="$1" t1="$2" t2="$3" t3="$4"
    local o1="<span foreground='#6c7086'>${t1}</span>"
    local o2="<span foreground='#6c7086'>${t2}</span>"
    local o3="<span foreground='#6c7086'>${t3}</span>"
    case "$idx" in
        1) o1="<span foreground='#a6e3a1' weight='bold'>[${t1}]</span>" ;;
        2) o2="<span foreground='#74c7ec' weight='bold'>[${t2}]</span>" ;;
        3) o3="<span foreground='#fab387' weight='bold'>[${t3}]</span>" ;;
    esac
    printf "%s <span foreground='#6c7086'>/</span> %s <span foreground='#6c7086'>/</span> %s" "$o1" "$o2" "$o3"
}

prof_idx=2
[ "$profile" = "low-power" ] && prof_idx=1
[ "$profile" = "performance" ] && prof_idx=3

rapl_idx=2
[ "$pl1_w" -le 25 ] && rapl_idx=1
[ "$pl1_w" -ge 40 ] && rapl_idx=3

if [ "$ac" = "0" ]; then
    hdr="<span foreground='#a6e3a1' weight='bold'>󰁹 ON BATTERY (-${power_w}W · ${bat_cap}%)</span>"
else
    hdr="<span foreground='#74c7ec' weight='bold'>󰚥 ON AC POWER (${power_w}W · ${bat_cap}%)</span>"
fi

tt="${hdr}  <span foreground='#6c7086'>(BAT / AC)</span>\n"
tt+="<span foreground='#cba6f7' weight='bold'>── Display &amp; Compositor ──────────────────────</span>\n"
tt+="  Refresh Rate (eDP-1):   $(pango_pair "$([ "$edp_hz" -le 65 ] 2>/dev/null && echo bat || echo ac)" "60 Hz" "165 Hz")\n"
tt+="  Blur / Shadows / Anim:  $(pango_pair "$([ "$blur_on" = "0" ] && echo bat || echo ac)" "Off" "On")\n"
tt+="  Unfocused Opacity:      $(pango_pair "$([ "$blur_on" = "0" ] && echo bat || echo ac)" "1.00 Opaque" "0.95 Glass")\n"
tt+="  Cursor &amp; Fullscreen:    <span foreground='#94e2d5'>HW Cursor Plane + Direct Scanout</span>\n"
tt+="\n<span foreground='#fab387' weight='bold'>── CPU, Thermals &amp; Fan (i7-12700H) ───────────</span>\n"
tt+="  ACPI Platform Profile:  $(pango_triple "$prof_idx" "low-power" "balanced" "perf")\n"
tt+="  RAPL Power (PL1/PL2):   $(pango_triple "$rapl_idx" "20/35W" "35/65W" "45/115W")\n"
tt+="  CPU Turbo Boost:        $(pango_pair "$([ "$no_turbo" = "1" ] && echo bat || echo ac)" "Off" "On")\n"
tt+="  HWP Dynamic Boost:      $(pango_pair "$([ "$hwp_boost" = "0" ] && echo bat || echo ac)" "Off" "On")\n"
tt+="  Energy Perf (EPP):      $(pango_pair "$([ "$epp" = "power" ] && echo bat || echo ac)" "power" "$epp")\n"
tt+="  PROCHOT Target:         $(pango_pair "$([ "$ac" = "0" ] && echo bat || echo ac)" "65°C" "85°C") <span foreground='#a6adc8'>(now ${cpu_temp}°C)</span>\n"
tt+="  ThinkFan Curve:         $(pango_pair "$([ "${fan_rpm:-0}" -eq 0 ] 2>/dev/null && echo bat || echo ac)" "0 RPM &lt;${fan_zero_up}°C" "${fan_rpm} RPM")\n"
tt+="\n<span foreground='#f9e2af' weight='bold'>── Graphics &amp; Media (Iris Xe + RTX A2000) ────</span>\n"
tt+="  Iris Xe iGPU Clock:     $(pango_pair "$([ "${igpu_max:-1400}" -le 700 ] 2>/dev/null && echo bat || echo ac)" "600 MHz" "1400 MHz") <span foreground='#a6adc8'>+ FBC/GuC</span>\n"
tt+="  RTX A2000 dGPU State:   $(pango_pair "$([ "$dgpu_state" = "D3cold" ] && echo bat || echo ac)" "D3cold Off" "$dgpu_state") <span foreground='#a6adc8'>+ S0ix</span>\n"
tt+="  Video Decode &amp; Vulkan:  <span foreground='#94e2d5'>Intel iHD VA-API + Mesa EGL/VK</span>\n"
tt+="\n<span foreground='#89b4fa' weight='bold'>── Storage, Radios &amp; Daemons ─────────────────</span>\n"
tt+="  PCIe ASPM Policy:       $(pango_pair "$([ "$aspm" = "powersupersave" ] && echo bat || echo ac)" "powersupersave" "$aspm")\n"
tt+="  NVMe Dirty Writeback:   $(pango_pair "$([ "${dirty_s:-15}" -ge 30 ] 2>/dev/null && echo bat || echo ac)" "60s" "15s") <span foreground='#a6adc8'>+ ext4 noatime</span>\n"
tt+="  Wi-Fi Power Save:       $(pango_pair "$([ "$wifi_ps" = "on" ] && echo bat || echo ac)" "On (scheme 3)" "Off")\n"
tt+="  Audio / Cam / Daemons:  <span foreground='#94e2d5'>HDA ${snd_ps}s · Docker ${docker_state} · BT ${bt_state}</span>\n"
tt+="<span foreground='#6c7086'><i>Left-click: Interactive TUI  ·  Right-click: Cycle Power Mode</i></span>"

if [ "$ac" = "0" ]; then
    printf '{"text":"󰌪 bat","class":"battery","tooltip":"%s"}\n' "$tt"
else
    printf '{"text":"󰚥 ac","class":"ac","tooltip":"%s"}\n' "$tt"
fi
