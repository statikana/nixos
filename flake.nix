{
  description = "ryan nixos system configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    claude-desktop.url = "github:danielbodart/claude-desktop";
  };

  outputs = { self, nixpkgs, home-manager, claude-desktop, ... }@inputs: {
    nixosConfigurations.ryan-nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./configuration.nix
        home-manager.nixosModules.home-manager
        claude-desktop.nixosModules.default
      ];
    };
  };

}
