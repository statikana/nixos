{ ... }: {

    programs.bash.shellAliases = {
        # Nix
        reb-offline = "~/nixos/rebuild.sh offline";
        reb = "~/nixos/rebuild.sh";
        gc = "nix-collect-garbage --delete-older-than 14d && sudo nix-collect-garbage --delete-older-than 14d";
        pks = "code ~/nixos/modules/packages.nix";
        l = "f(){find **/*$1*; unset -f f; } f";

        nfm = "nixfmt --indent=4 ~/nixos && echo \"Done\"";

        # Other tools
        p3 = "python3";

        ff = "fastfetch";

        # Common folders
        docs = "cd ~/Documents";
        me = "cd ~/statikana";
        mast = "cd ~/mast";
    };
}
