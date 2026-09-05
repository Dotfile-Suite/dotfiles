# You can build these directly using 'nix build .#example'
{pkgs ? import <nixpkgs> {}}: rec {
  #################### Packages with external source ####################

  # example = pkgs.callPackage ./example {};

  # sops built from the Dotfile-Suite fork (age-only, every other key
  # backend stripped) instead of nixpkgs' own copy -- see
  # pkgs/dfs-sops/default.nix and hosts/common/secrets/README.md.
  dfs-sops = pkgs.callPackage ./dfs-sops {};
}
