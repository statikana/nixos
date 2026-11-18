{ lib, ... }: {

    home.stateVersion = "26.05";
    home.enableNixpkgsReleaseCheck = false; # syabuuuuu

    imports = lib.pipe ./. [
        builtins.readDir
        (lib.filterAttrs (
            name: type:
            !(lib.hasPrefix "_" name)
            && (name != "default.nix")
            && (
                lib.hasSuffix ".nix" name
                || (type == "directory" && builtins.pathExists (./. + "/${name}/default.nix"))
            )
        ))
        (lib.mapAttrsToList (name: _: ./. + "/${name}"))
    ];
}
