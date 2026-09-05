{
  pkgs,
  config,
  ...
}: {
  programs.git = {
    enable = true;
    settings = {
      core.editor = "nvim";
      init.defaultBranch = "master";
      merge.conflictStyle = "zdiff3";
      branch.sort = "committerdate";
      push.autoSetupRemote = true;

      #sendmail = {
      #    from = "Example User <example@example.com>";
      #    smtpServer = "127.0.0.1";
      #    smtpServerPort = 1025;
      #    smtpUser = "example";
      #    smtpPassword = "/HxMou3HXfi+RaEAxry8w6Ws0tybPdVPHJxpSNvAC0I="; # This is a localhost only password so should be fine
      #};
    };
    # user.name/user.email come from the per-user sops-managed identity
    # file instead of a hardcoded value here -- see
    # hosts/common/secrets/default.nix and hosts/common/secrets/README.md.
    # Git silently skips a missing include path, so this is safe even
    # before that secret exists; it just errors normally at commit time
    # ("Please tell me who you are") instead of committing under someone
    # else's shared identity.
    includes = [
      {path = "${config.home.homeDirectory}/.config/git/identity.gitconfig";}
    ];
    signing = {
      # Reuses the sops-managed SSH identity (see
      # hosts/common/secrets/default.nix) instead of a separate GPG
      # key. Signs directly with the private key file rather than going
      # through ssh-agent, since nothing here loads this key into one.
      format = "ssh";
      key = "${config.home.homeDirectory}/.ssh/id_ed25519";
      signer = "${pkgs.openssh}/bin/ssh-keygen";
      signByDefault = true;
    };
    lfs.enable = true;
    ignores = [
      ".direnv/"
      ".devenv/"
      ".venv/"
      ".env"
    ];
  };
  home.packages = with pkgs; [
    git-extras
  ];
}
