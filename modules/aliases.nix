{ ... }:

{

    programs.bash.shellAliases = {
        rebuild = "sudo nixos-rebuild switch";
        config = "nvim /etc/nixos/configuration.nix";
        garbage = "nix-store --gc";
        pks = "nvim /etc/nixos/modules/packages.nix";
        alias = "nvim /etc/nixos/modules/aliases.nix";
        nfm = "nixfmt /etc/nixos/*.nix /etc/nixos/modules/*.nix && echo \"Done\"";
        z = "zoxide";
        
        p3 = "python3";
        
        # File edits

        # Directories
        docs = "cd ~/documents";
        me = "cd ~/documents/github/statikana";
        mast = "cd ~/documents/github/mast";
        ec = "cd /etc/nixos";
        mods = "cd /etc/nixos/modules";
    };
}
