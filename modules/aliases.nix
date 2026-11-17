{ ... }: {

    programs.bash.shellAliases = {
        # Nix
        # reb = "git add .; git commit -m \"rebuild \" && git push && sudo nixos-rebuild switch --flake ~/nixos#ryan-nixos";
        reb-offline = "~/nixos/rebuld.sh offline";
        reb = "~/nixos/rebuild.sh";
        gc = "sudo nix-collect-garbage -j auto --delete-older-than 2w -v && nix-store --gc -j auto -v";
        pks = "code ~/nixos/modules/packages.nix";

        nfm = "nixfmt --indent=4 ~/nixos/**.*.nix && echo \"Done\"";

        # Other tools
        p3 = "python3";

        ff = "fastfetch";

        # Common folders
        docs = "cd ~/Documents";
        me = "cd ~/Documents/github/statikana";
        mast = "cd ~/Documents/github/mast";

        # Services
        cfm = "systemctl status cloudflared-tunnel-8054cb48-cd44-4232-8cb1-fd0c7540c73a";
    };
}
