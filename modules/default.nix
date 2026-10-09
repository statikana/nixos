{ ... }:

{
  imports = [
    ./packages.nix
    ./hardware-configuration.nix
    ./aliases.nix
    ./nvidia.nix
    ./hyprland.nix
    ./audio.nix
];
}
