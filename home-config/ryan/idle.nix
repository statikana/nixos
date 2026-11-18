{ pkgs, ... }: {
    programs.hyprlock = {
        enable = true;
        settings = {
            general = {
                hide_cursor = false;
                ignore_empty_input = true;
                immediate_render = true;
            };

            # Simultaneous unlock: touch the ThinkPad fingerprint sensor at any time (via
            # native D-Bus fprintd) OR type your password and press Enter (via PAM).
            auth = {
                pam = {
                    enabled = true;
                    module = "hyprlock";
                };
                fingerprint = {
                    enabled = true;
                    ready_message = "󰈷  Touch fingerprint sensor to unlock";
                    present_message = "󰈷  Verifying fingerprint...";
                    retry_delay = 250;
                };
            };

            background = [
                {
                    monitor = "";
                    path = "/home/ryan/nixos/assets/glassy_bands.png";
                    color = "rgba(17, 17, 27, 1.0)";
                    blur_passes = 3;
                    blur_size = 6;
                    brightness = 0.72;
                    vibrancy = 0.1696;
                }
            ];

            label = [
                # 12-hour Clock
                {
                    monitor = "";
                    text = "$TIME12";
                    color = "rgba(205, 214, 244, 0.96)";
                    font_size = 68;
                    font_family = "JetBrainsMono Nerd Font Bold";
                    position = "0, 175";
                    halign = "center";
                    valign = "center";
                }
                # Date Subtitle
                {
                    monitor = "";
                    text = "cmd[update:60000] date +'%A, %B %-d'";
                    color = "rgba(166, 173, 200, 0.90)";
                    font_size = 17;
                    font_family = "JetBrainsMono Nerd Font";
                    position = "0, 98";
                    halign = "center";
                    valign = "center";
                }
                # User Header
                {
                    monitor = "";
                    text = "󰌾  $USER";
                    color = "rgba(137, 180, 250, 0.92)";
                    font_size = 14;
                    font_family = "JetBrainsMono Nerd Font";
                    position = "0, -18";
                    halign = "center";
                    valign = "center";
                }
                # Live Fingerprint Status Prompt
                {
                    monitor = "";
                    text = "$FPRINTPROMPT";
                    color = "rgba(147, 153, 178, 0.90)";
                    font_size = 13;
                    font_family = "JetBrainsMono Nerd Font";
                    position = "0, -138";
                    halign = "center";
                    valign = "center";
                }
            ];

            input-field = [
                {
                    monitor = "";
                    size = "340, 52";
                    position = "0, -76";
                    halign = "center";
                    valign = "center";
                    outline_thickness = 2;
                    rounding = 8;
                    dots_size = 0.26;
                    dots_spacing = 0.22;
                    dots_center = true;
                    outer_color = "rgba(137, 180, 250, 0.65)";
                    inner_color = "rgba(22, 22, 34, 0.88)";
                    font_color = "rgba(205, 214, 244, 1.0)";
                    font_family = "JetBrainsMono Nerd Font";
                    check_color = "rgba(116, 199, 236, 0.85)";
                    fail_color = "rgba(243, 139, 168, 0.90)";
                    fail_text = "<i>$FAIL ($ATTEMPTS)</i>";
                    capslock_color = "rgba(249, 226, 175, 0.90)";
                    placeholder_text = "Enter password...";
                    fade_on_empty = false;
                }
            ];
        };
    };

    services.hypridle = {
        enable = true;
        settings = {
            general = {
                lock_cmd = "pidof hyprlock || hyprlock";
                before_sleep_cmd = "loginctl lock-session";
                after_sleep_cmd = "hyprctl dispatch 'hl.dsp.dpms(\"on\")'";
            };

            listener = [
                {
                    timeout = 150; # 2.5 min: dim backlight
                    on-timeout = "${pkgs.brightnessctl}/bin/brightnessctl -s set 10";
                    on-resume = "${pkgs.brightnessctl}/bin/brightnessctl -r";
                }
                {
                    timeout = 300; # 5 min: lock
                    on-timeout = "loginctl lock-session";
                }
                {
                    timeout = 330; # 5.5 min: screen off
                    on-timeout = "hyprctl dispatch 'hl.dsp.dpms(\"off\")'";
                    on-resume = "hyprctl dispatch 'hl.dsp.dpms(\"on\")'";
                }
                {
                    timeout = 900; # 15 min: suspend
                    on-timeout = "systemctl suspend";
                }
            ];
        };
    };
}
