{ pkgs, ... }: {
    programs.hyprlock = {
        enable = true;
        settings = {
            background = [
                {
                    monitor = "";
                    path = "/home/ryan/Downloads/glassy_bands.png";
                    blur_passes = 2;
                    blur_size = 4;
                }
            ];
            input-field = [
                {
                    monitor = "";
                    size = "250, 60";
                    outline_thickness = 2;
                    dots_center = true;
                    placeholder_text = "Password...";
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
