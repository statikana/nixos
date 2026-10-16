{ ... }: {
    programs.bash = {
        enable = true;
        bashrcExtra = "eval \"$(zoxide init bash)\"";
    };
}