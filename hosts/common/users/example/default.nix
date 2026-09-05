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
  # an ordinary account and the same home-manager config as the primary
  # user below -- not the sops-managed SSH identity or admin groups, which
  # stay scoped to `username`. Extend this if a real multi-user host wants
  # per-user descriptions/groups instead of these generic defaults.
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
  ];

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

  sops = {
    age.keyFile = "${home}/.config/sops/age/keys.txt";

    # SSH identity used for server logins and GitHub auth (see
    # home/common/core/cli/ssh.nix for the client-side wiring). The
    # committed secrets/ssh.yaml is only a placeholder until it's replaced
    # with a real, locally-generated key -- see secrets/README.md.
    secrets."id_ed25519" = {
      sopsFile = ./secrets/ssh.yaml;
      path = "${home}/.ssh/id_ed25519";
      owner = username;
      mode = "0400";
      restartUnits = ["ssh-id-ed25519-pubkey.service"];
    };
  };

  # Derives ~/.ssh/id_ed25519.pub from the sops-managed private key on every
  # activation, and again whenever the private key content changes. Without
  # this, a stale .pub left over from a previous key silently wins: OpenSSH
  # prefers reading a companion .pub file over deriving one from the private
  # key, so a mismatched sibling breaks pubkey auth in a confusing way.
  systemd.services."ssh-id-ed25519-pubkey" = {
    description = "Derive ~/.ssh/id_ed25519.pub from the sops-managed private key";
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      User = username;
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.openssh}/bin/ssh-keygen -y -f ${home}/.ssh/id_ed25519 > ${home}/.ssh/id_ed25519.pub'";
    };
  };

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
