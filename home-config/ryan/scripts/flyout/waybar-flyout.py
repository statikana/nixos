#!/usr/bin/env python3
"""
Windows-11-inspired GTK4 Layer-Shell Flyout Center for Waybar.
Provides 3 crisp, sharp-cornered tabs:
  - hwmon : Live CPU, RAM/Swap, Package/NVMe/dGPU thermals, ThinkFan mode switch, Top Procs
  - quick : Wi-Fi, Bluetooth, Mic, Keep-Awake tiles, Volume & Brightness sliders, DNS/WARP/Tor, Media
  - power : Battery hero status, Power Profile switch, BAT/AC hardware optimizations summary

Runs as a lightweight warm daemon (0% CPU when hidden, <5ms popup on click)
controlled via $XDG_RUNTIME_DIR/waybar-flyout.sock.
"""

import glob
import os
import re
import socket
import subprocess
import sys
import threading
import time

# Build a clean environment for child processes BEFORE GTK4 preload vars matter
CLEAN_ENV = os.environ.copy()
for _k in ("LD_PRELOAD", "LD_LIBRARY_PATH", "PYTHONPATH", "GI_TYPELIB_PATH"):
    CLEAN_ENV.pop(_k, None)
_std_bins = "/run/wrappers/bin:/home/ryan/.nix-profile/bin:/etc/profiles/per-user/ryan/bin:/run/current-system/sw/bin"
CLEAN_ENV["PATH"] = f"{_std_bins}:{CLEAN_ENV.get('PATH', '')}"

import gi  # noqa: E402

gi.require_version("Gdk", "4.0")
gi.require_version("Gtk", "4.0")
gi.require_version("Gtk4LayerShell", "1.0")
from gi.repository import Gdk, GLib, Gtk, Gtk4LayerShell, Pango  # noqa: E402

RUNTIME_DIR = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
SOCK_PATH = os.path.join(RUNTIME_DIR, "waybar-flyout.sock")
SCRIPTS_DIR = "/home/ryan/nixos/home-config/ryan/scripts"

CSS = """
window.flyout-backdrop {
    background-color: transparent;
}

.flyout-card {
    background-color: #161622;
    border: 1px solid #2e3044;
    border-radius: 6px;
    padding: 15px;
    box-shadow: 0 12px 32px rgba(0, 0, 0, 0.65);
    color: #cdd6f4;
    font-family: "JetBrainsMono Nerd Font", "JetBrains Mono", sans-serif;
    font-size: 13.5px;
}

.tab-bar {
    background-color: #11111b;
    border: 1px solid #26283a;
    border-radius: 4px;
    padding: 3px;
    margin-bottom: 6px;
}

button.tab-btn {
    background: transparent;
    border: 1px solid transparent;
    border-radius: 3px;
    padding: 8px 12px;
    color: #7f849c;
    font-weight: 600;
    font-size: 13px;
    box-shadow: none;
}

button.tab-btn:hover {
    color: #cdd6f4;
    background-color: rgba(205, 214, 244, 0.06);
}

button.tab-btn.active {
    background-color: rgba(137, 180, 250, 0.15);
    border: 1px solid rgba(137, 180, 250, 0.5);
    color: #89b4fa;
}

.section-box {
    background-color: #11111b;
    border: 1px solid #252738;
    border-radius: 4px;
    padding: 12px 14px;
}

.section-title {
    color: #cdd6f4;
    font-weight: 600;
    font-size: 13.5px;
}

.section-value {
    color: #a6adc8;
    font-weight: 600;
    font-size: 13px;
}

.dim-label {
    color: #6c7086;
    font-size: 12px;
}

.sub-label {
    color: #9399b2;
    font-size: 12.5px;
}

.stat-cell {
    background-color: #161622;
    border: 1px solid #242637;
    border-radius: 4px;
    padding: 8px 10px;
}

.stat-key {
    color: #6c7086;
    font-size: 11.5px;
}

.stat-val {
    color: #cdd6f4;
    font-weight: 600;
    font-size: 13px;
}

.stat-val.warn {
    color: #f9e2af;
}

.stat-val.crit {
    color: #f38ba8;
}

.stat-val.good {
    color: #a6e3a1;
}

progressbar trough {
    min-height: 8px;
    border-radius: 3px;
    background-color: #232536;
}

progressbar progress {
    min-height: 8px;
    border-radius: 3px;
    background-color: #89b4fa;
}

progressbar.warn progress {
    background-color: #f9e2af;
}

progressbar.crit progress {
    background-color: #f38ba8;
}

progressbar.good progress {
    background-color: #a6e3a1;
}

.seg-bar {
    background-color: #161622;
    border: 1px solid #26283a;
    border-radius: 4px;
    padding: 3px;
}

button.seg-btn {
    background: transparent;
    border: 1px solid transparent;
    border-radius: 3px;
    padding: 7px 10px;
    color: #7f849c;
    font-size: 13px;
    font-weight: 500;
    box-shadow: none;
}

button.seg-btn:hover {
    color: #cdd6f4;
    background-color: rgba(205, 214, 244, 0.06);
}

button.seg-btn.active {
    background-color: rgba(137, 180, 250, 0.16);
    border: 1px solid #89b4fa;
    color: #89b4fa;
    font-weight: 600;
}

.tile-wrap {
    background-color: #11111b;
    border: 1px solid #26283a;
    border-radius: 4px;
}

.tile-wrap.active {
    background-color: rgba(137, 180, 250, 0.14);
    border: 1px solid rgba(137, 180, 250, 0.55);
}

button.tile-main {
    background: transparent;
    border: none;
    border-radius: 3px;
    padding: 10px 12px;
    color: #cdd6f4;
    box-shadow: none;
}

button.tile-main:hover {
    background-color: rgba(205, 214, 244, 0.06);
}

.tile-wrap.active button.tile-main {
    color: #89b4fa;
}

button.tile-more {
    background: transparent;
    border: none;
    border-left: 1px solid rgba(205, 214, 244, 0.09);
    border-radius: 0 3px 3px 0;
    padding: 0 12px;
    font-size: 15px;
    color: #7f849c;
    box-shadow: none;
}

button.tile-more:hover {
    color: #cdd6f4;
    background-color: rgba(205, 214, 244, 0.08);
}

.tile-title {
    font-weight: 600;
    font-size: 13px;
}

.tile-sub {
    color: #7f849c;
    font-size: 11.5px;
}

.tile-wrap.active .tile-sub {
    color: #a6adc8;
}

button.icon-btn {
    background-color: #161622;
    border: 1px solid #26283a;
    border-radius: 4px;
    padding: 6px 11px;
    font-size: 16px;
    color: #cdd6f4;
    box-shadow: none;
}

button.icon-btn:hover {
    border: 1px solid #89b4fa;
    color: #89b4fa;
}

button.icon-btn.muted {
    color: #6c7086;
}

button.action-btn {
    background-color: #11111b;
    border: 1px solid #282a3d;
    border-radius: 4px;
    padding: 9px 14px;
    color: #bac2de;
    font-size: 13px;
    font-weight: 500;
    box-shadow: none;
}

button.action-btn:hover {
    background-color: rgba(137, 180, 250, 0.14);
    border: 1px solid #89b4fa;
    color: #89b4fa;
}

scale trough {
    min-height: 8px;
    border-radius: 3px;
    background-color: #232536;
}

scale highlight {
    min-height: 8px;
    border-radius: 3px;
    background-color: #89b4fa;
}

scale slider {
    min-width: 16px;
    min-height: 16px;
    margin: -5px 0;
    border-radius: 4px;
    background-color: #cdd6f4;
    border: 1px solid #89b4fa;
    box-shadow: none;
}

.proc-row {
    font-size: 12px;
    color: #a6adc8;
}
"""


def _ensure_hypr_env(env):
    if "HYPRLAND_INSTANCE_SIGNATURE" not in env:
        hypr_dir = os.path.join(RUNTIME_DIR, "hypr")
        if os.path.isdir(hypr_dir):
            entries = sorted(os.listdir(hypr_dir))
            if entries:
                env["HYPRLAND_INSTANCE_SIGNATURE"] = entries[0]
    return env


def read_file(path, default=""):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            return f.read().strip()
    except OSError:
        return default


def read_int(path, default=0):
    val = read_file(path, "")
    try:
        return int(val)
    except ValueError:
        return default


def run_out(cmd, timeout=1.5):
    try:
        res = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            timeout=timeout,
            env=_ensure_hypr_env(CLEAN_ENV.copy()),
        )
        return res.stdout.strip(), res.returncode
    except Exception:
        return "", 1


def spawn_detached(cmd):
    subprocess.Popen(
        cmd,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
        env=_ensure_hypr_env(CLEAN_ENV.copy()),
    )


class TelemetryReader:
    """Fast sysfs / procfs state reader reusing the logic from scripts/stats & scripts/power."""

    def __init__(self):
        self.prev_cpu = None
        self.last_cpu_pct = 0

    def sample_cpu_pct(self):
        line = read_file("/proc/stat").splitlines()
        if not line:
            return self.last_cpu_pct
        parts = line[0].split()
        nums = [int(x) for x in parts[1:9]]
        idle = nums[3] + nums[4]
        total = sum(nums)
        if self.prev_cpu is not None:
            dt = total - self.prev_cpu[0]
            di = idle - self.prev_cpu[1]
            if dt > 0:
                self.last_cpu_pct = max(0, min(100, int(100 * (dt - di) / dt)))
        self.prev_cpu = (total, idle)
        return self.last_cpu_pct

    def read_hwmon_fast(self):
        cpu_pct = self.sample_cpu_pct()
        load_parts = read_file("/proc/loadavg", "0.00 0.00 0.00").split()
        load_str = " · ".join(load_parts[:3])

        freqs = []
        for p in glob.glob("/sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_cur_freq"):
            v = read_int(p, 0)
            if v > 0:
                freqs.append(v / 1_000_000.0)
        avg_ghz = sum(freqs) / len(freqs) if freqs else 0.0
        max_ghz = max(freqs) if freqs else 0.0

        pl1 = read_int("/sys/class/powercap/intel-rapl:0/constraint_0_power_limit_uw", 0) // 1_000_000
        pl2 = read_int("/sys/class/powercap/intel-rapl:0/constraint_1_power_limit_uw", 0) // 1_000_000

        # Memory & Swap (/proc/meminfo)
        mem = {}
        for ln in read_file("/proc/meminfo").splitlines():
            if ":" in ln:
                k, rest = ln.split(":", 1)
                toks = rest.strip().split()
                if toks and toks[0].isdigit():
                    mem[k] = int(toks[0])
        mt = mem.get("MemTotal", 1)
        ma = mem.get("MemAvailable", mt)
        mu = max(0, mt - ma)
        ram_pct = int(100 * mu / max(1, mt))
        st = mem.get("SwapTotal", 0)
        sf = mem.get("SwapFree", 0)
        su = max(0, st - sf)

        # ThinkPad thermal + coretemp + nvme + fan + dGPU
        tp_raw = read_file("/proc/acpi/ibm/thermal", "")
        tp_temps = [
            int(x)
            for x in tp_raw.replace("temperatures:", "").split()
            if x.lstrip("-").isdigit() and int(x) > 0
        ]
        pkg_temp = max(tp_temps) if tp_temps else 40

        nvme_temp = "?"
        core_min, core_max = 999, 0
        for h in glob.glob("/sys/class/hwmon/hwmon*"):
            hname = read_file(os.path.join(h, "name"))
            if hname == "nvme":
                t = read_int(os.path.join(h, "temp1_input"), 0)
                if t > 0:
                    nvme_temp = f"{t // 1000}°C"
            elif hname == "coretemp":
                for ti in glob.glob(os.path.join(h, "temp*_input")):
                    lbl = read_file(ti.replace("_input", "_label"))
                    if lbl.startswith("Core"):
                        ct = read_int(ti, 0) // 1000
                        core_min = min(core_min, ct)
                        core_max = max(core_max, ct)

        fan_txt = read_file("/proc/acpi/ibm/fan", "")
        m_rpm = re.search(r"speed:\s*(\d+)", fan_txt)
        fan_rpm = int(m_rpm.group(1)) if m_rpm else 0
        m_lvl = re.search(r"level:\s*(\S+)", fan_txt)
        fan_lvl = m_lvl.group(1) if m_lvl else "?"
        fan_mode = read_file(os.path.join(RUNTIME_DIR, "fan-mode"), "auto") or "auto"

        dgpu = read_file("/sys/bus/pci/devices/0000:01:00.0/power_state", "?")

        return {
            "cpu_pct": cpu_pct,
            "avg_ghz": avg_ghz,
            "max_ghz": max_ghz,
            "load_str": load_str,
            "pl1": pl1,
            "pl2": pl2,
            "ram_pct": ram_pct,
            "used_gib": mu / 1048576.0,
            "total_gib": mt / 1048576.0,
            "avail_gib": ma / 1048576.0,
            "swap_used_gib": su / 1048576.0,
            "swap_total_gib": st / 1048576.0,
            "pkg_temp": pkg_temp,
            "core_spread": f"{core_min}–{core_max}°C" if core_max > 0 else f"{pkg_temp}°C",
            "nvme_temp": nvme_temp,
            "dgpu": dgpu,
            "fan_rpm": fan_rpm,
            "fan_lvl": fan_lvl,
            "fan_mode": fan_mode,
        }

    def read_top_procs(self):
        out, _ = run_out(["ps", "-eo", "pcpu=,rss=,comm=", "--sort=-pcpu"], timeout=0.6)
        rows = []
        for ln in out.splitlines()[:4]:
            parts = ln.strip().split(None, 2)
            if len(parts) == 3:
                pcpu, rss_s, comm = parts
                try:
                    gib = int(rss_s) / 1048576.0
                    mem_s = f"{gib:.1f}G" if gib >= 1.0 else f"{int(rss_s) // 1024}M"
                except ValueError:
                    mem_s = "?"
                rows.append((comm[:20], f"{float(pcpu):4.1f}%", mem_s))
        return rows

    def read_power_fast(self):
        ac = read_int("/sys/class/power_supply/AC/online", 1)
        cap = read_int("/sys/class/power_supply/BAT0/capacity", 0)
        status = read_file("/sys/class/power_supply/BAT0/status", "Unknown")
        power_uw = read_int("/sys/class/power_supply/BAT0/power_now", 0)
        power_w = power_uw / 1_000_000.0
        en_now = read_int("/sys/class/power_supply/BAT0/energy_now", 0)
        en_full = read_int("/sys/class/power_supply/BAT0/energy_full", 1)
        en_des = read_int("/sys/class/power_supply/BAT0/energy_full_design", 1)
        cycles = read_int("/sys/class/power_supply/BAT0/cycle_count", 0)
        stop_thr = read_int("/sys/class/power_supply/BAT0/charge_control_end_threshold", 100)

        health = int(round(100.0 * en_full / max(1, en_des)))
        eta_str = ""
        if power_uw > 500_000:
            if status == "Discharging":
                hrs = en_now / power_uw
                eta_str = f"{int(hrs)}h {int((hrs % 1) * 60):02d}m left"
            elif status == "Charging" and en_full > en_now:
                hrs = (en_full - en_now) / power_uw
                eta_str = f"{int(hrs)}h {int((hrs % 1) * 60):02d}m to full"

        mode = read_file(os.path.join(RUNTIME_DIR, "power-mode"), "balanced") or "balanced"
        acpi_prof = read_file("/sys/firmware/acpi/platform_profile", "unknown")
        no_turbo = read_int("/sys/devices/system/cpu/intel_pstate/no_turbo", 0)
        epp = read_file("/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference", "?")
        pl1 = read_int("/sys/class/powercap/intel-rapl:0/constraint_0_power_limit_uw", 0) // 1_000_000
        pl2 = read_int("/sys/class/powercap/intel-rapl:0/constraint_1_power_limit_uw", 0) // 1_000_000
        aspm_raw = read_file("/sys/module/pcie_aspm/parameters/policy", "")
        m_aspm = re.search(r"\[([^\]]+)\]", aspm_raw)
        aspm = m_aspm.group(1) if m_aspm else (aspm_raw or "?")
        dgpu = read_file("/sys/bus/pci/devices/0000:01:00.0/power_state", "?")

        return {
            "ac": ac,
            "cap": cap,
            "status": status,
            "power_w": power_w,
            "health": health,
            "cycles": cycles,
            "stop_thr": stop_thr,
            "eta_str": eta_str,
            "mode": mode,
            "acpi_prof": acpi_prof,
            "turbo": "Off" if no_turbo == 1 else "On",
            "epp": epp,
            "rapl": f"{pl1}W / {pl2}W",
            "aspm": aspm,
            "dgpu": "D3cold Off" if dgpu == "D3cold" else dgpu,
            "hz": "60 Hz (BAT)" if ac == 0 else "165 Hz (AC)",
        }

    def read_quick_state(self):
        bri_cur = read_int("/sys/class/backlight/intel_backlight/brightness", 100)
        bri_max = max(1, read_int("/sys/class/backlight/intel_backlight/max_brightness", 100))
        bri_pct = int(round(100.0 * bri_cur / bri_max))

        wifi_blocked = False
        bt_blocked = False
        for rfk in glob.glob("/sys/class/rfkill/rfkill*"):
            rtype = read_file(os.path.join(rfk, "type"))
            soft = read_int(os.path.join(rfk, "soft"), 0)
            if rtype == "wlan" and soft == 1:
                wifi_blocked = True
            elif rtype == "bluetooth" and soft == 1:
                bt_blocked = True

        vol_out, _ = run_out(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"], timeout=0.6)
        vol_pct = 50
        vol_muted = "[MUTED]" in vol_out
        m_v = re.search(r"Volume:\s*([0-9.]+)", vol_out)
        if m_v:
            vol_pct = int(round(float(m_v.group(1)) * 100))

        mic_out, _ = run_out(["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"], timeout=0.6)
        mic_muted = "[MUTED]" in mic_out
        mic_pct = 100
        m_m = re.search(r"Volume:\s*([0-9.]+)", mic_out)
        if m_m:
            mic_pct = int(round(float(m_m.group(1)) * 100))

        wifi_ssid = "Disconnected"
        wifi_connected = False
        if not wifi_blocked:
            nm_out, _ = run_out(["nmcli", "-t", "-f", "TYPE,STATE,CONNECTION", "dev"], timeout=0.8)
            for ln in nm_out.splitlines():
                parts = ln.split(":", 2)
                if len(parts) >= 3 and parts[0] in ("wifi", "ethernet") and parts[1] == "connected":
                    wifi_connected = True
                    wifi_ssid = parts[2] if parts[0] == "wifi" else f"Wired ({parts[2]})"
                    break
            if not wifi_connected:
                wifi_ssid = "Enabled"
        else:
            wifi_ssid = "Off"

        bt_on = False
        bt_sub = "Off"
        if not bt_blocked:
            bt_show, _ = run_out(["bluetoothctl", "show"], timeout=0.7)
            if "Powered: yes" in bt_show:
                bt_on = True
                bt_devs, _ = run_out(["bluetoothctl", "devices", "Connected"], timeout=0.7)
                dev_lines = [d for d in bt_devs.splitlines() if d.startswith("Device ")]
                if len(dev_lines) == 1:
                    bt_sub = dev_lines[0].split(" ", 2)[2][:18]
                elif len(dev_lines) > 1:
                    bt_sub = f"{len(dev_lines)} connected"
                else:
                    bt_sub = "On"

        idle_out, _ = run_out(["systemctl", "--user", "is-active", "hypridle.service"], timeout=0.6)
        awake_on = idle_out != "active"

        _, rc_tor = run_out(["systemctl", "is-active", "--quiet", "tor.service"], timeout=0.5)
        _, rc_dir = run_out(["systemctl", "is-active", "--quiet", "dnscrypt-proxy-direct.service"], timeout=0.5)
        _, rc_tdns = run_out(["systemctl", "is-active", "--quiet", "dnscrypt-proxy-tor.service"], timeout=0.5)
        warp_up = os.path.isdir("/sys/class/net/warp0")

        if rc_tdns == 0 and rc_tor == 0:
            dns_mode, dns_detail = "tor", "Tor 9040 + DoH"
        elif warp_up and rc_dir == 0:
            dns_mode, dns_detail = "warp", "WARP Tunnel + DoH"
        elif rc_dir == 0:
            dns_mode, dns_detail = "direct", "Cloudflare DoH"
        else:
            dns_mode, dns_detail = "off", "DHCP Direct"

        p_stat, rc_p = run_out(["playerctl", "status"], timeout=0.5)
        media_active = rc_p == 0 and p_stat in ("Playing", "Paused")
        media_title = ""
        if media_active:
            meta, _ = run_out(
                ["playerctl", "metadata", "--format", "{{title}} — {{artist}}"],
                timeout=0.5,
            )
            media_title = meta.strip(" —")[:42] or "Media Active"

        return {
            "vol_pct": max(0, min(100, vol_pct)),
            "vol_muted": vol_muted,
            "mic_pct": mic_pct,
            "mic_muted": mic_muted,
            "bri_pct": max(5, min(100, bri_pct)),
            "wifi_on": not wifi_blocked,
            "wifi_ssid": wifi_ssid,
            "bt_on": bt_on,
            "bt_sub": bt_sub,
            "awake_on": awake_on,
            "dns_mode": dns_mode,
            "dns_detail": dns_detail,
            "media_active": media_active,
            "media_playing": p_stat == "Playing",
            "media_title": media_title,
        }


class FlyoutWindow(Gtk.Window):
    def __init__(self, app: "FlyoutApp", initial_tab: str):
        super().__init__(application=app)
        self.app_ref = app
        self.telemetry = app.telemetry
        self.active_tab = initial_tab if initial_tab in ("hwmon", "quick", "power") else "quick"
        self.alive = True
        self.last_vol_drag = 0.0
        self.last_bri_drag = 0.0
        self._vol_timer = None
        self._bri_timer = None
        self._pending_vol = None
        self._pending_bri = None
        self._updating_sliders = False

        self.add_css_class("flyout-backdrop")
        Gtk4LayerShell.init_for_window(self)
        Gtk4LayerShell.set_namespace(self, "waybar-flyout")
        Gtk4LayerShell.set_layer(self, Gtk4LayerShell.Layer.TOP)
        Gtk4LayerShell.set_exclusive_zone(self, 0)
        Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.TOP, True)
        Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.BOTTOM, True)
        Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.LEFT, True)
        Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.RIGHT, True)
        Gtk4LayerShell.set_keyboard_mode(self, Gtk4LayerShell.KeyboardMode.ON_DEMAND)

        key_ctrl = Gtk.EventControllerKey()
        key_ctrl.connect("key-pressed", self._on_key_pressed)
        self.add_controller(key_ctrl)

        overlay = Gtk.Overlay()
        self.set_child(overlay)

        # Transparent click-outside backdrop (only receives clicks outside `card`)
        backdrop = Gtk.Box()
        backdrop.set_hexpand(True)
        backdrop.set_vexpand(True)
        bg_click = Gtk.GestureClick()
        bg_click.connect("released", lambda *_: self.close_flyout())
        backdrop.add_controller(bg_click)
        overlay.set_child(backdrop)

        # Top-right Flyout Card (NO gesture controller attached so child buttons/sliders receive all clicks!)
        card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        card.add_css_class("flyout-card")
        card.set_can_target(True)
        card.set_halign(Gtk.Align.END)
        card.set_valign(Gtk.Align.START)
        card.set_margin_top(8)
        card.set_margin_end(10)
        card.set_size_request(436, -1)
        overlay.add_overlay(card)

        # Top Tab Switcher
        tab_bar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=3)
        tab_bar.add_css_class("tab-bar")
        tab_bar.set_homogeneous(True)
        self.tab_btns = {}
        for tid, label in [
            ("hwmon", "󰘚  Hardware"),
            ("quick", "󰒓  Controls"),
            ("power", "󰁹  Power"),
        ]:
            b = Gtk.Button(label=label)
            b.add_css_class("tab-btn")
            b.connect("clicked", lambda _, t=tid: self.switch_tab(t))
            tab_bar.append(b)
            self.tab_btns[tid] = b
        card.append(tab_bar)

        self.stack = Gtk.Stack()
        self.stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE)
        self.stack.set_transition_duration(110)
        card.append(self.stack)

        self._build_hwmon_tab()
        self._build_quick_tab()
        self._build_power_tab()

        self.switch_tab(self.active_tab)
        self._timer_id = GLib.timeout_add(2000, self._periodic_refresh)
        self.connect("close-request", self._on_close_req)

    def _on_key_pressed(self, _ctrl, keyval, _keycode, _state):
        if keyval == Gdk.KEY_Escape:
            self.close_flyout()
            return True
        return False

    def _on_close_req(self, *_):
        self.alive = False
        if self._timer_id:
            GLib.source_remove(self._timer_id)
            self._timer_id = None
        if self.app_ref.win is self:
            self.app_ref.win = None
        return False

    def close_flyout(self):
        if self.alive:
            self.close()

    def switch_tab(self, tab_id: str):
        if tab_id not in self.tab_btns:
            return
        self.active_tab = tab_id
        for tid, btn in self.tab_btns.items():
            if tid == tab_id:
                btn.add_css_class("active")
            else:
                btn.remove_css_class("active")
        self.stack.set_visible_child_name(tab_id)
        self.refresh_active_tab()

    def _periodic_refresh(self):
        if not self.alive:
            return False
        self.refresh_active_tab()
        return True

    def refresh_active_tab(self):
        if not self.alive:
            return
        if self.active_tab == "hwmon":
            self._update_hwmon_ui(self.telemetry.read_hwmon_fast())
            threading.Thread(target=self._bg_procs, daemon=True).start()
        elif self.active_tab == "power":
            self._update_power_ui(self.telemetry.read_power_fast())
        elif self.active_tab == "quick":
            threading.Thread(target=self._bg_quick, daemon=True).start()

    # ===================== TAB 1: HARDWARE MONITOR =====================
    def _build_hwmon_tab(self):
        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)

        # CPU Box
        cpu_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=7)
        cpu_box.add_css_class("section-box")
        r1 = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        t_cpu = Gtk.Label(label="󰘚  Processor", xalign=0)
        t_cpu.add_css_class("section-title")
        t_cpu.set_hexpand(True)
        self.lbl_cpu_val = Gtk.Label(label="0% · 0.00 GHz", xalign=1)
        self.lbl_cpu_val.add_css_class("section-value")
        r1.append(t_cpu)
        r1.append(self.lbl_cpu_val)
        self.bar_cpu = Gtk.ProgressBar()
        self.lbl_cpu_sub = Gtk.Label(label="Load 0.00   ·   RAPL 0W / 0W", xalign=0)
        self.lbl_cpu_sub.add_css_class("dim-label")
        cpu_box.append(r1)
        cpu_box.append(self.bar_cpu)
        cpu_box.append(self.lbl_cpu_sub)
        root.append(cpu_box)

        # Memory Box
        mem_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=7)
        mem_box.add_css_class("section-box")
        r2 = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        t_mem = Gtk.Label(label="󰍛  Memory", xalign=0)
        t_mem.add_css_class("section-title")
        t_mem.set_hexpand(True)
        self.lbl_mem_val = Gtk.Label(label="0.0 / 0.0 GiB", xalign=1)
        self.lbl_mem_val.add_css_class("section-value")
        r2.append(t_mem)
        r2.append(self.lbl_mem_val)
        self.bar_mem = Gtk.ProgressBar()
        self.lbl_mem_sub = Gtk.Label(label="Available 0.0 GiB   ·   Swap 0.0 GiB", xalign=0)
        self.lbl_mem_sub.add_css_class("dim-label")
        mem_box.append(r2)
        mem_box.append(self.bar_mem)
        mem_box.append(self.lbl_mem_sub)
        root.append(mem_box)

        # Sensors 3-column row
        sens_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        sens_row.set_homogeneous(True)
        self.lbl_pkg_temp = self._make_stat_cell(sens_row, "Package Temp", "40°C")
        self.lbl_nvme_temp = self._make_stat_cell(sens_row, "NVMe SSD", "--")
        self.lbl_dgpu_state = self._make_stat_cell(sens_row, "RTX A2000", "--")
        root.append(sens_row)

        # Fan Control Segmented Box
        fan_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        fan_box.add_css_class("section-box")
        rf = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        tf = Gtk.Label(label="󰈐  ThinkFan Cooling", xalign=0)
        tf.add_css_class("section-title")
        tf.set_hexpand(True)
        self.lbl_fan_rpm = Gtk.Label(label="0 RPM", xalign=1)
        self.lbl_fan_rpm.add_css_class("dim-label")
        rf.append(tf)
        rf.append(self.lbl_fan_rpm)
        fan_box.append(rf)

        seg_fan = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=3)
        seg_fan.add_css_class("seg-bar")
        seg_fan.set_homogeneous(True)
        self.fan_btns = {}
        for mode, label in [("quiet", "󰠝  Quiet"), ("auto", "󰈐  Auto"), ("max", "󰈐  Max")]:
            b = Gtk.Button(label=label)
            b.add_css_class("seg-btn")
            b.connect("clicked", lambda _, m=mode: self._set_fan_mode(m))
            seg_fan.append(b)
            self.fan_btns[mode] = b
        fan_box.append(seg_fan)
        root.append(fan_box)

        # Top Processes Box
        proc_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        proc_box.add_css_class("section-box")
        tp = Gtk.Label(label="Top Active Processes", xalign=0)
        tp.add_css_class("dim-label")
        proc_box.append(tp)
        self.proc_labels = []
        for _ in range(4):
            lbl = Gtk.Label(label="", xalign=0)
            lbl.add_css_class("proc-row")
            proc_box.append(lbl)
            self.proc_labels.append(lbl)
        root.append(proc_box)

        # Footer Launchers
        foot = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        foot.set_homogeneous(True)
        btn_tui = Gtk.Button(label="󰘚  Per-Core TUI")
        btn_tui.add_css_class("action-btn")
        btn_tui.connect(
            "clicked",
            lambda *_: self._launch_and_close(
                ["wezterm", "start", "--class", "stats-tui", "--", "bash", f"{SCRIPTS_DIR}/stats/stats-tui.sh"]
            ),
        )
        btn_btop = Gtk.Button(label="󰄨  Open btop")
        btn_btop.add_css_class("action-btn")
        btn_btop.connect(
            "clicked",
            lambda *_: self._launch_and_close(["wezterm", "start", "--class", "btop", "--", "btop"]),
        )
        foot.append(btn_tui)
        foot.append(btn_btop)
        root.append(foot)

        self.stack.add_named(root, "hwmon")

    def _make_stat_cell(self, parent_box, key_txt, val_txt):
        cell = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=3)
        cell.add_css_class("stat-cell")
        k = Gtk.Label(label=key_txt, xalign=0)
        k.add_css_class("stat-key")
        v = Gtk.Label(label=val_txt, xalign=0)
        v.add_css_class("stat-val")
        v.set_ellipsize(Pango.EllipsizeMode.END)
        cell.append(k)
        cell.append(v)
        parent_box.append(cell)
        return v

    def _set_bar_level(self, bar: Gtk.ProgressBar, pct: int, warn_at=75, crit_at=90):
        bar.set_fraction(max(0.0, min(1.0, pct / 100.0)))
        bar.remove_css_class("warn")
        bar.remove_css_class("crit")
        if pct >= crit_at:
            bar.add_css_class("crit")
        elif pct >= warn_at:
            bar.add_css_class("warn")

    def _update_hwmon_ui(self, d):
        if not self.alive:
            return
        self.lbl_cpu_val.set_text(f"{d['cpu_pct']}%  ·  {d['avg_ghz']:.2f} GHz")
        self._set_bar_level(self.bar_cpu, d["cpu_pct"], 70, 88)
        self.lbl_cpu_sub.set_text(f"Load {d['load_str']}   ·   PL1/2 {d['pl1']}W / {d['pl2']}W")

        self.lbl_mem_val.set_text(f"{d['used_gib']:.1f} / {d['total_gib']:.1f} GiB ({d['ram_pct']}%)")
        self._set_bar_level(self.bar_mem, d["ram_pct"], 75, 88)
        self.lbl_mem_sub.set_text(
            f"Avail {d['avail_gib']:.1f} GiB   ·   Swap {d['swap_used_gib']:.1f}/{d['swap_total_gib']:.1f} GiB"
        )

        self.lbl_pkg_temp.set_text(f"{d['pkg_temp']}°C ({d['core_spread']})")
        self.lbl_pkg_temp.remove_css_class("warn")
        self.lbl_pkg_temp.remove_css_class("crit")
        if d["pkg_temp"] >= 80:
            self.lbl_pkg_temp.add_css_class("crit")
        elif d["pkg_temp"] >= 65:
            self.lbl_pkg_temp.add_css_class("warn")

        self.lbl_nvme_temp.set_text(d["nvme_temp"])
        self.lbl_dgpu_state.set_text("D3cold (Off)" if d["dgpu"] == "D3cold" else d["dgpu"])

        self.lbl_fan_rpm.set_text(f"{d['fan_rpm']} RPM  ·  lvl {d['fan_lvl']}")
        for m, btn in self.fan_btns.items():
            if m == d["fan_mode"]:
                btn.add_css_class("active")
            else:
                btn.remove_css_class("active")

    def _bg_procs(self):
        rows = self.telemetry.read_top_procs()
        GLib.idle_add(self._apply_procs, rows)

    def _apply_procs(self, rows):
        if not self.alive:
            return False
        for i, lbl in enumerate(self.proc_labels):
            if i < len(rows):
                name, cpu_s, mem_s = rows[i]
                lbl.set_text(f"{name:<22} {cpu_s:>6}   {mem_s:>6}")
            else:
                lbl.set_text("")
        return False

    def _set_fan_mode(self, mode: str):
        for m, btn in self.fan_btns.items():
            if m == mode:
                btn.add_css_class("active")
            else:
                btn.remove_css_class("active")

        def worker():
            run_out(["bash", f"{SCRIPTS_DIR}/fan/fan-{mode}.sh"], timeout=3.0)
            GLib.idle_add(self.refresh_active_tab)

        threading.Thread(target=worker, daemon=True).start()

    # ===================== TAB 2: QUICK SETTINGS =====================
    def _build_quick_tab(self):
        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)

        # 2x2 Windows-11-style Quick Toggle Grid
        grid = Gtk.Grid(column_spacing=8, row_spacing=8)
        grid.set_column_homogeneous(True)

        self.tile_wifi = self._make_quick_tile(
            "󰤨  Wi-Fi",
            "Checking...",
            on_toggle=self._toggle_wifi,
            on_more=lambda: self._launch_and_close(
                ["wezterm", "start", "--class", "nmtui", "--", "nmtui"]
            ),
        )
        self.tile_bt = self._make_quick_tile(
            "󰂯  Bluetooth",
            "Checking...",
            on_toggle=self._toggle_bt,
            on_more=lambda: self._launch_and_close(
                ["wezterm", "start", "--class", "bluetuith", "--", "bluetuith"]
            ),
        )
        self.tile_mic = self._make_quick_tile(
            "󰍬  Microphone",
            "Ready",
            on_toggle=self._toggle_mic,
        )
        self.tile_awake = self._make_quick_tile(
            "󰈈  Keep Awake",
            "Normal sleep",
            on_toggle=self._toggle_awake,
        )

        grid.attach(self.tile_wifi["wrap"], 0, 0, 1, 1)
        grid.attach(self.tile_bt["wrap"], 1, 0, 1, 1)
        grid.attach(self.tile_mic["wrap"], 0, 1, 1, 1)
        grid.attach(self.tile_awake["wrap"], 1, 1, 1, 1)
        root.append(grid)

        # Volume & Brightness Sliders Section
        sliders_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        sliders_box.add_css_class("section-box")

        # Speaker Slider Row
        vol_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        self.btn_mute = Gtk.Button(label="󰕾")
        self.btn_mute.add_css_class("icon-btn")
        self.btn_mute.connect("clicked", lambda *_: self._toggle_speaker_mute())
        self.scale_vol = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 1)
        self.scale_vol.set_draw_value(False)
        self.scale_vol.set_hexpand(True)
        self.scale_vol.connect("value-changed", self._on_vol_slider)
        self.lbl_vol = Gtk.Label(label="100%", width_chars=5, xalign=1)
        self.lbl_vol.add_css_class("sub-label")
        btn_mixer = Gtk.Button(label="󰺢")
        btn_mixer.add_css_class("icon-btn")
        btn_mixer.set_tooltip_text("Open Wiremix Audio Mixer")
        btn_mixer.connect(
            "clicked",
            lambda *_: self._launch_and_close(
                ["wezterm", "start", "--class", "wiremix", "--", "wiremix"]
            ),
        )
        vol_row.append(self.btn_mute)
        vol_row.append(self.scale_vol)
        vol_row.append(self.lbl_vol)
        vol_row.append(btn_mixer)
        sliders_box.append(vol_row)

        # Brightness Slider Row
        bri_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        bri_lbl_icon = Gtk.Button(label="󰃠")
        bri_lbl_icon.add_css_class("icon-btn")
        bri_lbl_icon.connect("clicked", lambda *_: self._step_brightness())
        self.scale_bri = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 5, 100, 1)
        self.scale_bri.set_draw_value(False)
        self.scale_bri.set_hexpand(True)
        self.scale_bri.connect("value-changed", self._on_bri_slider)
        self.lbl_bri = Gtk.Label(label="100%", width_chars=5, xalign=1)
        self.lbl_bri.add_css_class("sub-label")
        bri_row.append(bri_lbl_icon)
        bri_row.append(self.scale_bri)
        bri_row.append(self.lbl_bri)
        sliders_box.append(bri_row)
        root.append(sliders_box)

        # DNS / Privacy Route Segmented Control
        dns_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        dns_box.add_css_class("section-box")
        rd = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        td = Gtk.Label(label="󰦝  Network Privacy / DNS", xalign=0)
        td.add_css_class("section-title")
        td.set_hexpand(True)
        self.lbl_dns_sub = Gtk.Label(label="DHCP Direct", xalign=1)
        self.lbl_dns_sub.add_css_class("dim-label")
        rd.append(td)
        rd.append(self.lbl_dns_sub)
        dns_box.append(rd)

        seg_dns = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=3)
        seg_dns.add_css_class("seg-bar")
        seg_dns.set_homogeneous(True)
        self.dns_btns = {}
        for mode, label in [("off", "DHCP"), ("direct", "DoH"), ("warp", "WARP"), ("tor", "Tor")]:
            b = Gtk.Button(label=label)
            b.add_css_class("seg-btn")
            b.connect("clicked", lambda _, m=mode: self._set_dns_mode(m))
            seg_dns.append(b)
            self.dns_btns[mode] = b
        dns_box.append(seg_dns)
        root.append(dns_box)

        # Media Player Strip (shown dynamically when media is active)
        self.media_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        self.media_box.add_css_class("section-box")
        self.lbl_media = Gtk.Label(label="No media", xalign=0)
        self.lbl_media.add_css_class("sub-label")
        self.lbl_media.set_hexpand(True)
        self.lbl_media.set_ellipsize(Pango.EllipsizeMode.END)
        b_prev = Gtk.Button(label="󰒮")
        b_prev.add_css_class("icon-btn")
        b_prev.connect("clicked", lambda *_: self._media_cmd("previous"))
        self.btn_play = Gtk.Button(label="󰐊")
        self.btn_play.add_css_class("icon-btn")
        self.btn_play.connect("clicked", lambda *_: self._media_cmd("play-pause"))
        b_next = Gtk.Button(label="󰒭")
        b_next.add_css_class("icon-btn")
        b_next.connect("clicked", lambda *_: self._media_cmd("next"))
        self.media_box.append(self.lbl_media)
        self.media_box.append(b_prev)
        self.media_box.append(self.btn_play)
        self.media_box.append(b_next)
        self.media_box.set_visible(False)
        root.append(self.media_box)

        self.stack.add_named(root, "quick")

    def _make_quick_tile(self, title: str, sub: str, on_toggle, on_more=None):
        wrap = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        wrap.add_css_class("tile-wrap")

        btn_main = Gtk.Button()
        btn_main.add_css_class("tile-main")
        btn_main.set_hexpand(True)
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=3)
        lbl_t = Gtk.Label(label=title, xalign=0)
        lbl_t.add_css_class("tile-title")
        lbl_s = Gtk.Label(label=sub, xalign=0)
        lbl_s.add_css_class("tile-sub")
        lbl_s.set_ellipsize(Pango.EllipsizeMode.END)
        vbox.append(lbl_t)
        vbox.append(lbl_s)
        btn_main.set_child(vbox)
        btn_main.connect("clicked", lambda *_: on_toggle())
        wrap.append(btn_main)

        if on_more is not None:
            btn_more = Gtk.Button(label="›")
            btn_more.add_css_class("tile-more")
            btn_more.connect("clicked", lambda *_: on_more())
            wrap.append(btn_more)

        return {"wrap": wrap, "title": lbl_t, "sub": lbl_s}

    def _set_tile_state(self, tile, active: bool, sub_text: str, title_text: str = None):
        if active:
            tile["wrap"].add_css_class("active")
        else:
            tile["wrap"].remove_css_class("active")
        tile["sub"].set_text(sub_text)
        if title_text:
            tile["title"].set_text(title_text)

    def _bg_quick(self):
        state = self.telemetry.read_quick_state()
        GLib.idle_add(self._apply_quick, state)

    def _apply_quick(self, s):
        if not self.alive:
            return False
        self._set_tile_state(self.tile_wifi, s["wifi_on"], s["wifi_ssid"])
        self._set_tile_state(self.tile_bt, s["bt_on"], s["bt_sub"])
        self._set_tile_state(
            self.tile_mic,
            not s["mic_muted"],
            "Muted" if s["mic_muted"] else f"Ready ({s['mic_pct']}%)",
            "󰍭  Microphone" if s["mic_muted"] else "󰍬  Microphone",
        )
        self._set_tile_state(
            self.tile_awake,
            s["awake_on"],
            "Screen stays on" if s["awake_on"] else "Normal dim/lock",
            "󰈈  Awake" if s["awake_on"] else "󰾪  Keep Awake",
        )

        self._updating_sliders = True
        now = time.monotonic()
        if now - self.last_vol_drag > 0.7:
            self.scale_vol.set_value(s["vol_pct"])
            self.lbl_vol.set_text("Mute" if s["vol_muted"] else f"{s['vol_pct']}%")
        if s["vol_muted"]:
            self.btn_mute.set_label("󰝟")
            self.btn_mute.add_css_class("muted")
        else:
            self.btn_mute.set_label("󰕾")
            self.btn_mute.remove_css_class("muted")

        if now - self.last_bri_drag > 0.7:
            self.scale_bri.set_value(s["bri_pct"])
            self.lbl_bri.set_text(f"{s['bri_pct']}%")
        self._updating_sliders = False

        self.lbl_dns_sub.set_text(s["dns_detail"])
        for m, btn in self.dns_btns.items():
            if m == s["dns_mode"]:
                btn.add_css_class("active")
            else:
                btn.remove_css_class("active")

        self.media_box.set_visible(s["media_active"])
        if s["media_active"]:
            self.lbl_media.set_text(s["media_title"])
            self.btn_play.set_label("󰏤" if s["media_playing"] else "󰐊")
        return False

    def _on_vol_slider(self, scale):
        if self._updating_sliders:
            return
        val = int(round(scale.get_value()))
        self.last_vol_drag = time.monotonic()
        self.lbl_vol.set_text(f"{val}%")
        self._pending_vol = val
        if self._vol_timer is None:
            self._vol_timer = GLib.timeout_add(35, self._flush_vol)

    def _flush_vol(self):
        self._vol_timer = None
        val = self._pending_vol
        if val is not None:
            threading.Thread(
                target=lambda: run_out(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", f"{val}%"], 0.5),
                daemon=True,
            ).start()
        return False

    def _on_bri_slider(self, scale):
        if self._updating_sliders:
            return
        val = max(5, int(round(scale.get_value())))
        self.last_bri_drag = time.monotonic()
        self.lbl_bri.set_text(f"{val}%")
        self._pending_bri = val
        if self._bri_timer is None:
            self._bri_timer = GLib.timeout_add(35, self._flush_bri)

    def _flush_bri(self):
        self._bri_timer = None
        val = self._pending_bri
        if val is not None:
            threading.Thread(
                target=lambda: run_out(["brightnessctl", "set", f"{val}%"], 0.5),
                daemon=True,
            ).start()
        return False

    def _step_brightness(self):
        cur = int(round(self.scale_bri.get_value()))
        nxt = 25 if cur >= 95 else min(100, ((cur // 25) + 1) * 25)
        self.scale_bri.set_value(nxt)

    def _toggle_speaker_mute(self):
        def worker():
            run_out(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"], 0.5)
            self._bg_quick()

        threading.Thread(target=worker, daemon=True).start()

    def _toggle_mic(self):
        def worker():
            run_out(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"], 0.5)
            self._bg_quick()

        threading.Thread(target=worker, daemon=True).start()

    def _toggle_wifi(self):
        def worker():
            run_out(["rfkill", "toggle", "wifi"], 0.8)
            time.sleep(0.25)
            self._bg_quick()

        threading.Thread(target=worker, daemon=True).start()

    def _toggle_bt(self):
        is_active = self.tile_bt["wrap"].has_css_class("active")

        def worker():
            if is_active:
                run_out(["bluetoothctl", "power", "off"], 1.0)
                run_out(["rfkill", "block", "bluetooth"], 0.8)
            else:
                run_out(["rfkill", "unblock", "bluetooth"], 0.8)
                time.sleep(0.2)
                run_out(["bluetoothctl", "power", "on"], 1.2)
            self._bg_quick()

        threading.Thread(target=worker, daemon=True).start()

    def _toggle_awake(self):
        is_awake = self.tile_awake["wrap"].has_css_class("active")

        def worker():
            action = "start" if is_awake else "stop"
            run_out(["systemctl", "--user", action, "hypridle.service"], 1.0)
            self._bg_quick()

        threading.Thread(target=worker, daemon=True).start()

    def _set_dns_mode(self, mode: str):
        for m, btn in self.dns_btns.items():
            if m == mode:
                btn.add_css_class("active")
            else:
                btn.remove_css_class("active")
        self.lbl_dns_sub.set_text("Switching...")

        def worker():
            run_out(["bash", f"{SCRIPTS_DIR}/dns/dns-{mode}.sh"], timeout=8.0)
            self._bg_quick()

        threading.Thread(target=worker, daemon=True).start()

    def _media_cmd(self, action: str):
        def worker():
            run_out(["playerctl", action], 0.6)
            time.sleep(0.15)
            self._bg_quick()

        threading.Thread(target=worker, daemon=True).start()

    # ===================== TAB 3: POWER & BATTERY =====================
    def _build_power_tab(self):
        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)

        # Battery Hero Box
        bat_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        bat_box.add_css_class("section-box")
        rb = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        self.lbl_bat_title = Gtk.Label(label="󰁹  Battery", xalign=0)
        self.lbl_bat_title.add_css_class("section-title")
        self.lbl_bat_title.set_hexpand(True)
        self.lbl_bat_draw = Gtk.Label(label="0.0 W", xalign=1)
        self.lbl_bat_draw.add_css_class("section-value")
        rb.append(self.lbl_bat_title)
        rb.append(self.lbl_bat_draw)
        self.bar_bat = Gtk.ProgressBar()
        self.lbl_bat_sub = Gtk.Label(label="Health --%  ·  Cycles --", xalign=0)
        self.lbl_bat_sub.add_css_class("dim-label")
        bat_box.append(rb)
        bat_box.append(self.bar_bat)
        bat_box.append(self.lbl_bat_sub)
        root.append(bat_box)

        # Power Profile Segmented Box
        prof_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        prof_box.add_css_class("section-box")
        rp = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        tp = Gtk.Label(label="󰾆  Power Profile", xalign=0)
        tp.add_css_class("section-title")
        tp.set_hexpand(True)
        self.lbl_acpi_prof = Gtk.Label(label="ACPI: balanced", xalign=1)
        self.lbl_acpi_prof.add_css_class("dim-label")
        rp.append(tp)
        rp.append(self.lbl_acpi_prof)
        prof_box.append(rp)

        seg_pwr = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=3)
        seg_pwr.add_css_class("seg-bar")
        seg_pwr.set_homogeneous(True)
        self.pwr_btns = {}
        for mode, label in [
            ("saver", "󰾅  Saver"),
            ("balanced", "󰾆  Balanced"),
            ("performance", "󰓅  Perf"),
        ]:
            b = Gtk.Button(label=label)
            b.add_css_class("seg-btn")
            b.connect("clicked", lambda _, m=mode: self._set_power_mode(m))
            seg_pwr.append(b)
            self.pwr_btns[mode] = b
        prof_box.append(seg_pwr)
        root.append(prof_box)

        # Active Optimizations Grid (reusing battery-changes.sh sysfs parameters)
        opt_grid = Gtk.Grid(column_spacing=8, row_spacing=8)
        opt_grid.set_column_homogeneous(True)
        self.opt_cells = {}
        specs = [
            ("hz", "Panel Refresh", 0, 0),
            ("turbo", "Turbo Boost", 1, 0),
            ("rapl", "RAPL PL1/PL2", 0, 1),
            ("epp", "CPU EPP", 1, 1),
            ("aspm", "PCIe ASPM", 0, 2),
            ("dgpu", "dGPU State", 1, 2),
        ]
        for key, label, col, row in specs:
            cell = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=3)
            cell.add_css_class("stat-cell")
            k = Gtk.Label(label=label, xalign=0)
            k.add_css_class("stat-key")
            v = Gtk.Label(label="--", xalign=0)
            v.add_css_class("stat-val")
            v.set_ellipsize(Pango.EllipsizeMode.END)
            cell.append(k)
            cell.append(v)
            opt_grid.attach(cell, col, row, 1, 1)
            self.opt_cells[key] = v
        root.append(opt_grid)

        # Footer TUI Launcher
        btn_ptui = Gtk.Button(label="󰌪  Open Full Power Optimizations TUI")
        btn_ptui.add_css_class("action-btn")
        btn_ptui.connect(
            "clicked",
            lambda *_: self._launch_and_close(
                [
                    "wezterm",
                    "start",
                    "--class",
                    "battery-changes",
                    "--",
                    "bash",
                    f"{SCRIPTS_DIR}/power/battery-changes.sh",
                    "--interactive",
                ]
            ),
        )
        root.append(btn_ptui)

        self.stack.add_named(root, "power")

    def _update_power_ui(self, d):
        if not self.alive:
            return
        src = "AC" if d["ac"] == 1 else "BAT"
        sign = "+" if d["status"] == "Charging" else ("-" if d["status"] == "Discharging" else "")
        self.lbl_bat_title.set_text(f"{'󰚥' if d['ac'] == 1 else '󰁹'}  {d['cap']}%  ·  {d['status']}")
        self.lbl_bat_draw.set_text(f"{src}  ·  {sign}{d['power_w']:.1f} W")

        self.bar_bat.set_fraction(max(0.0, min(1.0, d["cap"] / 100.0)))
        self.bar_bat.remove_css_class("warn")
        self.bar_bat.remove_css_class("crit")
        self.bar_bat.remove_css_class("good")
        if d["status"] == "Charging":
            self.bar_bat.add_css_class("good")
        elif d["cap"] <= 15:
            self.bar_bat.add_css_class("crit")
        elif d["cap"] <= 30:
            self.bar_bat.add_css_class("warn")

        parts = []
        if d["eta_str"]:
            parts.append(d["eta_str"])
        parts.append(f"Health {d['health']}%")
        parts.append(f"Cycles {d['cycles']}")
        if d["stop_thr"] < 100:
            parts.append(f"Cap {d['stop_thr']}%")
        self.lbl_bat_sub.set_text("  ·  ".join(parts))

        self.lbl_acpi_prof.set_text(f"ACPI: {d['acpi_prof']}")
        for m, btn in self.pwr_btns.items():
            if m == d["mode"]:
                btn.add_css_class("active")
            else:
                btn.remove_css_class("active")

        for k, lbl in self.opt_cells.items():
            lbl.set_text(str(d.get(k, "--")))

    def _set_power_mode(self, mode: str):
        for m, btn in self.pwr_btns.items():
            if m == mode:
                btn.add_css_class("active")
            else:
                btn.remove_css_class("active")

        def worker():
            run_out(["bash", f"{SCRIPTS_DIR}/power/power-{mode}.sh"], timeout=3.0)
            GLib.idle_add(self.refresh_active_tab)

        threading.Thread(target=worker, daemon=True).start()

    def _launch_and_close(self, cmd):
        spawn_detached(cmd)
        self.close_flyout()


class FlyoutApp(Gtk.Application):
    def __init__(self, initial_tab=None):
        super().__init__(application_id="org.ryan.WaybarFlyout")
        self.initial_tab = initial_tab
        self.telemetry = TelemetryReader()
        self.telemetry.sample_cpu_pct()
        self.win = None
        self.sock = None

    def do_startup(self):
        Gtk.Application.do_startup(self)
        provider = Gtk.CssProvider()
        provider.load_from_string(CSS)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )
        self._setup_socket()
        self.hold()

    def do_activate(self):
        if self.initial_tab:
            tab = self.initial_tab
            self.initial_tab = None
            self.handle_command(f"open:{tab}")

    def _setup_socket(self):
        try:
            if os.path.exists(SOCK_PATH):
                os.unlink(SOCK_PATH)
        except OSError:
            pass
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.bind(SOCK_PATH)
        self.sock.listen(8)
        self.sock.setblocking(False)
        GLib.io_add_watch(self.sock.fileno(), GLib.IO_IN, self._on_sock_accept)

    def _on_sock_accept(self, _fd, _cond):
        try:
            conn, _ = self.sock.accept()
            data = conn.recv(256).decode("utf-8", errors="replace").strip()
            conn.close()
            if data:
                self.handle_command(data)
        except OSError:
            pass
        return True

    def handle_command(self, cmd: str):
        if cmd == "close":
            if self.win is not None:
                self.win.close_flyout()
            return
        if cmd == "quit":
            if self.win is not None:
                self.win.close_flyout()
            self.release()
            self.quit()
            return

        if ":" in cmd:
            action, tab = cmd.split(":", 1)
        else:
            action, tab = "toggle", cmd

        if action == "toggle":
            if self.win is not None and self.win.alive:
                if self.win.active_tab == tab:
                    self.win.close_flyout()
                else:
                    self.win.switch_tab(tab)
                    self.win.present()
            else:
                self.win = FlyoutWindow(self, tab)
                self.win.present()
        elif action == "open":
            if self.win is not None and self.win.alive:
                self.win.switch_tab(tab)
                self.win.present()
            else:
                self.win = FlyoutWindow(self, tab)
                self.win.present()


def main():
    initial_tab = None
    if len(sys.argv) >= 3 and sys.argv[1] == "--tab":
        initial_tab = sys.argv[2]
    app = FlyoutApp(initial_tab=initial_tab)
    app.run([])


if __name__ == "__main__":
    main()
