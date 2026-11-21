{ pkgs, ... }:
{
    fonts = {
        enableDefaultPackages = true;

        packages = with pkgs; [
            nerd-fonts.jetbrains-mono
            ibm-plex
            inter

            # LaTeX / LyX OpenType & TrueType fonts (screen display and XeTeX/LuaTeX non-TeX fonts)
            lmodern
            gyre-fonts
            cm_unicode
            libertine
            libertinus
            stix-two
            eb-garamond
            crimson
            crimson-pro
            fira
            fira-mono
            noto-fonts
            source-serif
            source-sans
            source-code-pro
            paratype-pt-serif
            paratype-pt-sans
            paratype-pt-mono
            cantarell-fonts
            iwona
        ];
    };
}
