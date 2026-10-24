#!/usr/bin/env bash
# Stylized Catppuccin Mocha Power Profile status & Pango tooltip for Waybar

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
mode=$(cat "$XDG_RUNTIME_DIR/power-mode" 2>/dev/null || echo balanced)
PROFILE=$(cat /sys/firmware/acpi/platform_profile 2>/dev/null || echo unknown)
PL1=$(($(cat /sys/class/powercap/intel-rapl:0/constraint_0_power_limit_uw 2>/dev/null || echo 0) / 1000000))
PL2=$(($(cat /sys/class/powercap/intel-rapl:0/constraint_1_power_limit_uw 2>/dev/null || echo 0) / 1000000))
DGPU=$(cat /sys/bus/pci/devices/0000:01:00.0/power_state 2>/dev/null || echo "?")

m_sav="<span foreground='#6c7086'>saver</span>"
m_bal="<span foreground='#6c7086'>balanced</span>"
m_prf="<span foreground='#6c7086'>performance</span>"

case "$mode" in
    saver)       m_sav="<span foreground='#a6e3a1' weight='bold'>[saver]</span>" ;;
    performance) m_prf="<span foreground='#fab387' weight='bold'>[performance]</span>" ;;
    *)           m_bal="<span foreground='#74c7ec' weight='bold'>[balanced]</span>" ;;
esac

if [ "$DGPU" = "D3cold" ]; then
    dgpu_str="<span foreground='#a6e3a1' weight='bold'>D3cold (0W Off)</span>"
else
    dgpu_str="<span foreground='#74c7ec' weight='bold'>${DGPU}</span>"
fi

tt="<span foreground='#74c7ec' weight='bold'>󰾆  System Power Profile</span>\n"
tt+="<span foreground='#45475a'>────────────────────────────────────────────</span>\n"
tt+="  Active Mode:   ${m_sav} <span foreground='#6c7086'>/</span> ${m_bal} <span foreground='#6c7086'>/</span> ${m_prf}\n"
tt+="  ACPI Profile:  <span foreground='#cdd6f4' weight='bold'>${PROFILE}</span>\n"
tt+="  RAPL PL1/PL2:  <span foreground='#74c7ec' weight='bold'>${PL1}W / ${PL2}W</span>\n"
tt+="  RTX A2000:     ${dgpu_str}\n"
tt+="<span foreground='#6c7086'><i>Left-click: Profile Menu  ·  Right-click: Cycle Mode</i></span>"

case "$mode" in
    performance)
        printf '{"text":"󰓅 perf","class":"performance","tooltip":"%s"}\n' "$tt"
        ;;
    saver)
        printf '{"text":"󰾅 saver","class":"saver","tooltip":"%s"}\n' "$tt"
        ;;
    *)
        printf '{"text":"󰾆 bal","class":"balanced","tooltip":"%s"}\n' "$tt"
        ;;
esac
