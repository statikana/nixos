{ ... }:

{

    programs.bash.shellAliases = {
        # Nix
        ec = "cd ~/nixos";
        mods = "cd ~/nixos/modules";
        rebuild = "sudo nixos-rebuild switch";
        config = "nvim ~/nixos/configuration.nix";
        garbage = "nix-store --gc";
        pks = "nvim ~/nixos/modules/packages.nix";
        alias = "nvim ~/nixos/modules/aliases.nix";

        nfm = "nixfmt --indent=4 ~/nixos/*.nix ~/nixos/modules/*.nix && echo \"Done\"";

        # Other tools
        z = "zoxide";
        p3 = "python3";

        # Common folders
        docs = "cd ~/documents";
        me = "cd ~/documents/github/statikana";
        mast = "cd ~/documents/github/mast";
    };
}
