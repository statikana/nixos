{ lib, ... }:
{
    imports = lib.pipe ./. [
		builtins.readDir(
			lib.filterAttrs (
				name: 
				type: name != "default.nix" && (type == "directory" || lib.hasSuffix ".nix" name)
			)
		)(
			lib.mapAttrsToList (
				name: _: ./. + "/${name}"
			)
		)
    ];
}