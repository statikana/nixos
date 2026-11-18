{ config, lib, ... }: {
    security = {
        pam.services = {
            # SDDM collects the password field BEFORE invoking PAM:
            # - If a password was typed, `unix-early` verifies it in <5ms, skips `fprintd`
            #   (`success=1`), unlocks GNOME Keyring, and logs in immediately with zero 30s hang.
            # - If the password field was left blank (press Enter), `unix-early` returns ignore
            #   immediately and `pam_fprintd.so` activates the Synaptics fingerprint reader.
            sddm = {
                useDefaultRules = lib.mkForce true;
                startSession = true;
                setLoginUid = true;
                lastlog = {
                    enable = true;
                    silent = true;
                };
                enableGnomeKeyring = true;
                rules = {
                    auth = {
                        login.enable = false;
                        unix-early = {
                            order = config.security.pam.services.sddm.rules.auth.fprintd.order - 10;
                            control = lib.mkForce "[success=1 new_authtok_reqd=done default=ignore]";
                        };
                    };
                    account.login.enable = false;
                    password.login.enable = false;
                    session.login.enable = false;
                };
            };

            # Hyprlock v0.9+ talks to fprintd natively over D-Bus in parallel with PAM password
            # auth (`auth:fingerprint:enabled = true` in idle.nix). Keep `fprintAuth = false`
            # here so PAM only checks typed passwords and never fights Hyprlock for the sensor.
            hyprlock = {
                fprintAuth = false;
                enableGnomeKeyring = true;
            };
        };

        sudo.extraRules = [
            {
                groups = [ "fan_ctl" ];
                commands = [
                    {
                        command = "/run/current-system/sw/bin/systemctl start thinkfan.service";
                        options = [ "NOPASSWD" ];
                    }
                    {
                        command = "/run/current-system/sw/bin/systemctl stop thinkfan.service";
                        options = [ "NOPASSWD" ];
                    }
                    {
                        command = "/run/current-system/sw/bin/systemctl restart thinkfan.service";
                        options = [ "NOPASSWD" ];
                    }
                    {
                        command = "/run/current-system/sw/bin/systemctl start thinkfan-auto.service";
                        options = [ "NOPASSWD" ];
                    }
                    {
                        command = "/run/current-system/sw/bin/systemctl start thinkfan-quiet.service";
                        options = [ "NOPASSWD" ];
                    }
                    {
                        command = "/run/current-system/sw/bin/systemctl start thinkfan-max.service";
                        options = [ "NOPASSWD" ];
                    }
                ];
            }
            {
                groups = [ "power_ctl" ];
                commands = [
                    {
                        command = "/run/current-system/sw/bin/systemctl start undervolt-performance.service";
                        options = [ "NOPASSWD" ];
                    }
                    {
                        command = "/run/current-system/sw/bin/systemctl start undervolt-balanced.service";
                        options = [ "NOPASSWD" ];
                    }
                    {
                        command = "/run/current-system/sw/bin/systemctl start undervolt-saver.service";
                        options = [ "NOPASSWD" ];
                    }
                    {
                        command = "/run/current-system/sw/bin/systemctl start dns-proxy-off.service";
                        options = [ "NOPASSWD" ];
                    }
                    {
                        command = "/run/current-system/sw/bin/systemctl start dns-proxy-direct.service";
                        options = [ "NOPASSWD" ];
                    }
                    {
                        command = "/run/current-system/sw/bin/systemctl start dns-proxy-warp.service";
                        options = [ "NOPASSWD" ];
                    }
                    {
                        command = "/run/current-system/sw/bin/systemctl start dns-proxy-tor.service";
                        options = [ "NOPASSWD" ];
                    }
                ];
            }
        ];
    };
}
