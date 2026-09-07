# PLACEHOLDER -- replace this file with the real output of, run on the
# target machine:
#
#   sudo nixos-generate-config --show-hardware-config > hosts/<this-host>/hardware-configuration.nix
#
# bootstrap.sh at the repo root does this for you -- see `./bootstrap.sh --help`.
# The values below are just enough for the flake to evaluate; they do not
# describe a real disk layout and this host will not boot as-is.
{
  lib,
  modulesPath,
  ...
}: {
  imports = [(modulesPath + "/installer/scan/not-detected.nix")];

  boot.initrd.availableKernelModules = [];
  boot.initrd.kernelModules = [];
  boot.kernelModules = [];
  boot.extraModulePackages = [];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  swapDevices = [];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
