{ lib, ... }:
{
    imports = lib.pipe ./. [
        # read files in this directory
        builtins.readDir
        (lib.filterAttrs (
            name: type:
            !(lib.hasPrefix "_" name)
            && (name != "default.nix")
            && (type == "directory" || lib.hasSuffix ".nix" name)
        ))
        (lib.mapAttrsToList (name: _: ./. + "/${name}"))
    ];
}
