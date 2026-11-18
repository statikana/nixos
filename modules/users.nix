{ ... }: {
    users.users."ryan" = {
        isNormalUser = true;
        description = "Ryan Peckham";
        extraGroups = [
            "networkmanager"
            "wheel"
            "docker"
            "input"
            "video"
            "fan_ctl"
            "power_ctl"
        ];
    };

}
