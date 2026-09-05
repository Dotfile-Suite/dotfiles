# Minimal home-manager base for any NixOS host: just the generic CLI/shell
# core. home.username and home.homeDirectory are intentionally NOT set
# here -- hosts/common/users/example/default.nix sets them per user when it
# wires this file into home-manager.users (once for the primary user, once
# per name in extraUsers). That's what makes this same file usable
# unmodified for every user on a host, instead of baking in one username.
{...}: {
  imports = [
    ./common/core
  ];

  home.stateVersion = "26.05";
}
