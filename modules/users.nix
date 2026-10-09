{ ... }: {
  users.users."ryan" = {
    isNormalUser = true;
    description = "Ryan Peckham";
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
    ];
  };
}