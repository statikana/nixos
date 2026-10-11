{ ... }: {
    users.users."ryan" = {
        isNormalUser = true;
        description = "Ryan Peckham";
        extraGroups = [
            "networkmanager"
            "wheel"
            "docker"
            "input"
        ];
    };

    home-manager.users."ryan" = { pkgs, ... }: {
        home.packages = [ ];
        programs.bash.enable = true;

        # The state version is required and should stay at the version you
        # originally installed.
        home.stateVersion = "26.05";
    };
}
