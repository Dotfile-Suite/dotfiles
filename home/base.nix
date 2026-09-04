# Minimal home-manager base for any NixOS host: just the generic CLI/shell
# core, plus the two values every home-manager config needs (username,
# homeDirectory). No desktop stack -- a real host's own home/<hostname>.nix
# opts into whatever it actually needs from ./common/optional (apps,
# desktops/hyprland, desktops/waybar, ...).
{
  config,
  username,
  ...
}: {
  imports = [
    ./common/core
  ];

  home = {
    inherit username;
    homeDirectory = "/home/${config.home.username}";
    stateVersion = "26.05";
  };
}
