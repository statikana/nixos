{ lib, ... }:
{
    imports = lib.pipe ./. [
        # read files in this directory
        builtins.readDir
        (lib.filterAttrs (
            name: type: name != "default.nix" && (type == "directory" || lib.hasSuffix ".nix" name) # read all directories and .nix files here
        ))
        (lib.mapAttrsToList (
            name: _: ./. + (builtins.trace "load: ${name}" "/${name}") # relative pathing
        ))
    ];
}
