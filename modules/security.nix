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
        ];
    };
}