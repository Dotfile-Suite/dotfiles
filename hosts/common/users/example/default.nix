{
  pkgs,
  lib,
  config,
  inputs,
  username,
  extraUsers ? [],
  ...
}: let
  ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
  home = "/home/${username}";

  # Additional, non-admin accounts (see flake.nix's `extraUsers`). They get
  # an ordinary account, the same home-manager config as the primary user,
  # and their own sops-managed SSH/git identity (see the `secrets` import
  # below) -- just not the primary's admin groups. Extend this if a real
  # multi-user host wants per-user descriptions/groups instead of these
  # generic defaults.
  mkExtraUser = name: {
    isNormalUser = true;
    description = name;
    shell = pkgs.zsh;
    extraGroups = ["networkmanager"];
    packages = [pkgs.home-manager];
  };
in {
  imports = [
    inputs.sops-nix.nixosModules.sops
  ]
  # One instance of hosts/common/secrets per user, giving each their own
  # SSH + git identity from hosts/common/secrets/<name>.yaml. See that
  # module and hosts/common/secrets/README.md.
  ++ map (name: import ../../secrets {inherit name;}) ([username] ++ extraUsers);

  users.users =
    {
      ${username} = {
        isNormalUser = true;
        description = "Example User";
        shell = pkgs.zsh;
        extraGroups = ["networkmanager" "wheel" "dialout"] ++ ifTheyExist ["wireshark" "docker" "libvirtd" "mysql" "network" "git"];
        packages = [pkgs.home-manager];
      };
    }
    // lib.genAttrs extraUsers mkExtraUser;

  # Single machine-wide admin decryption key, used by sops-nix (running as
  # root during activation) to decrypt every user's hosts/common/secrets/
  # <name>.yaml -- they all share one age recipient (see
  # hosts/common/secrets/.sops.yaml), so this doesn't need to be per-user.
  sops.age.keyFile = "${home}/.config/sops/age/keys.txt";

  # Every user on this host -- the primary user and any extraUsers -- gets
  # the same home-manager config, based off home/<hostname>.nix. That file
  # itself doesn't set home.username/homeDirectory (see home/base.nix), so
  # it's identical for every user; each one is individualized here, by
  # wrapping it with its own name via `imports`.
  home-manager.users = lib.genAttrs ([username] ++ extraUsers) (name: {
    imports = [../../../../home/${config.networking.hostName}.nix];
    home.username = lib.mkDefault name;
    home.homeDirectory = lib.mkDefault "/home/${name}";
  });
}
