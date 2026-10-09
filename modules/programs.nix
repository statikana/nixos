{ ... }: {
    programs = {
        nix-ld.enable = true;

        firefox.enable = true;

        steam.enable = true;

        mtr.enable = true;

        gnupg.agent = {
            enable = true;
            enableSSHSupport = true;
        };
    };
}