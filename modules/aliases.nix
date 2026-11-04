{ ... }:

{

    programs.bash.shellAliases = {
        # Nix
        n = "cd ~/nixos && code .";
        e = "code";
        reb = "sudo nixos-rebuild switch --flake ~/nixos#ryan-nixos";
        gc = "nix-store --gc";
        pks = "code ~/nixos/modules/packages.nix";

        nfm = "nixfmt --indent=4 ~/nixos/*.nix ~/nixos/modules/*.nix && echo \"Done\"";

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
