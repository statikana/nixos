{ ... }: {
    security = {
        sudo.extraRules = [
            {
                users = [ "ryan" ];
                commands = [
                    {
                        command = "/run/current-system/sw/bin/systemctl start thinkfan.service";
                        options = [ "NOPASSWD" ];
                    }
                    {
                        command = "/run/current-system/sw/bin/systemctl stop thinkfan.service";
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