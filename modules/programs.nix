{ ... }: {
    programs = {
        nix-ld.enable = true;

        programs.firefox.enable = true;

        programs.steam.enable = true;

        mtr.enable = true;
        
        gnupg.agent = {
            enable = true;
            enableSSHSupport = true;
        }
    };
}