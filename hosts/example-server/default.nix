# example-server -- generic, minimal host skeleton.
#
# Intended role (see docs/REDESIGN.md): headless, hosts data/services that one
# or more example-client machines connect to. Deliberately bare for now --
# boot loader, networking, and the shared core/user modules only. Copy this
# directory (bootstrap.sh does this for you) to start a real machine, then
# layer on whatever hosts/common/optional modules and hardware config that
# machine actually needs.
{
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./hardware-configuration.nix

    # Common config
    ../common/core

    # User config
    ../common/users/example
  ];

  # Derived from this directory's own name, so copying/renaming a host
  # directory to stand up a new machine also renames the machine -- nothing
  # else in this file needs editing for that.
  networking.hostName = builtins.baseNameOf (toString ./.);

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  system.stateVersion = "26.05";
}
