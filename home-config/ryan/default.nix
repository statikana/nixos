{ lib, ... }:
{
    # home-manager.users."ryan" = ...

    home.stateVersion = "26.05";
    home.enableNixpkgsReleaseCheck = false; # syabuuuuu

    imports = lib.pipe ./. [
        # read files in this directory
        builtins.readDir
        (lib.filterAttrs (
            name: type:
            !(lib.hasPrefix "_" name)
            && (name != "default.nix")
            && (type == "directory" || lib.hasSuffix ".nix" name) # read all directories and .nix files here
        ))
        (lib.mapAttrsToList (
            name: _: ./. + (builtins.trace "home cfg: ${name}" "/${name}") # relative pathing
        ))
    ];

}
