# Curried module (same shape as hosts/common/optional/wireguard.nix's
# {ip}: {...}: {...} pattern): the caller supplies which user this secret
# set belongs to, since specialArgs has no way to hand each invocation of
# the same module a different value.
#
# Imported once per user -- the primary `username` and each of
# `extraUsers` -- from hosts/common/users/example/default.nix. Gives that
# user their own SSH identity and git commit identity, both sourced from
# one encrypted ./<name>.yaml -- see ./README.md for how that file is
# created (bootstrap.sh automates it; manual sops commands are documented
# there as a fallback).
{name}: {config, pkgs, ...}: let
  secretsFile = ./. + "/${name}.yaml";
  home = "/home/${name}";
  pubkeyService = "ssh-id-ed25519-pubkey-${name}";
in {
  assertions = [
    {
      assertion = builtins.pathExists secretsFile;
      message = ''
        Missing hosts/common/secrets/${name}.yaml for user '${name}'
        (referenced via flake.nix's username/extraUsers). Run
        ./bootstrap.sh <host> to generate one automatically, or pass
        --key-${name}=<path-to-private-key> to supply an existing one.
        See hosts/common/secrets/README.md.
      '';
    }
  ];

  sops.secrets."${name}-id_ed25519" = {
    sopsFile = secretsFile;
    key = "id_ed25519";
    path = "${home}/.ssh/id_ed25519";
    owner = name;
    mode = "0400";
    restartUnits = ["${pubkeyService}.service"];
  };

  sops.secrets."${name}-git-identity" = {
    sopsFile = secretsFile;
    key = "git_identity";
    path = "${home}/.config/git/identity.gitconfig";
    owner = name;
    mode = "0400";
  };

  # Derives ~/.ssh/id_ed25519.pub from the sops-managed private key on every
  # activation, and again whenever the private key changes (restartUnits
  # above). Without this, a stale .pub left over from a previous key
  # silently wins: OpenSSH prefers reading a companion .pub file over
  # deriving one from the private key, so a mismatched sibling breaks
  # pubkey auth in a confusing way. One instance per user.
  systemd.services."${pubkeyService}" = {
    description = "Derive ${home}/.ssh/id_ed25519.pub from the sops-managed private key (${name})";
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      User = name;
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.openssh}/bin/ssh-keygen -y -f ${home}/.ssh/id_ed25519 > ${home}/.ssh/id_ed25519.pub'";
    };
  };
}
