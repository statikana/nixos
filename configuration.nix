{
    config,
    pkgs,
    lib,
    ...
}:

{
	imports = [
		"/etc/nixos/modules"
	];

	# Use the systemd-boot EFI boot loader.


	# Set your time zone.

	# Enable the X11 windowing system.
	# You can disable this if you're only using the Wayland session.
	services.xserver.enable = true;

	# Enable the KDE Plasma Desktop Environment.
	services.displayManager.sddm.enable = true;
	services.desktopManager.plasma6.enable = true;

	# Configure keymap in X11
	services.xserver.xkb = {
		layout = "us";
		variant = "";
	};


	nixpkgs.config.allowUnfree = true;

	nix.settings.experimental-features = [
		"nix-command"
		"flakes"
	];

	environment.systemPackages = with pkgs; [

	];


	# Smallest supported version of NixOS
	system.stateVersion = "26.05";
}
