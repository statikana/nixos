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
        docs = "cd ~/documents";
        me = "cd ~/documents/github/statikana";
        mast = "cd ~/documents/github/mast";

        # Services
        cfm = "systemctl status cloudflared-tunnel-8054cb48-cd44-4232-8cb1-fd0c7540c73a";
        # updresume = "cp ~/downloads/ryan_peckham_resume.pdf ~/documents/github/statikana/peckhamr.com/static/ryan_peckham_resume/pdf && cp ~/downloads/ryan_peckham_resume.pdf ~/documents/github/statikana/peckhamr.com/static/ryan_peckham_resume_" + (builtins.strftime "%Y_%m_%d" builtins.currentTime) + ".pdf && git add . && git commit -m 'update resume' && git push";
    };
}
