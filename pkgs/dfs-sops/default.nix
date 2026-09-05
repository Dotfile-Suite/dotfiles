# dfs-sops: sops built from Dotfile-Suite/sops instead of nixpkgs' own
# copy. That fork strips every key-management backend except age (no PGP,
# no AWS/GCP/Azure/HuaweiCloud KMS, no HashiCorp Vault) -- see that repo's
# dfs/README.md for why and how it stays in sync with upstream. This repo
# only uses age (see hosts/common/secrets/), so nothing here loses
# capability; it just can't silently reach for something else.
{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  pname = "dfs-sops";
  version = "unstable-2026-09-05";

  src = fetchFromGitHub {
    owner = "Dotfile-Suite";
    repo = "sops";
    # Pin to a specific commit, not a branch -- bump deliberately (the same
    # way flake.lock inputs are), not by whatever main happens to be at
    # build time. Dotfile-Suite/template's dfs-fork-sync workflow is what
    # keeps that repo's main safe to bump to.
    rev = "85bdb23bc990a52ed2b93c750d041efac8d78bc8";
    # Placeholder -- `nix build .#myPkgs.x86_64-linux.dfs-sops` once on a
    # machine with Nix and paste the hash it reports back here.
    hash = lib.fakeHash;
  };

  # Same story: build once, paste the real hash Nix reports.
  vendorHash = lib.fakeHash;

  subPackages = ["cmd/sops"];

  ldflags = [
    "-s"
    "-w"
    "-X github.com/getsops/sops/v3/version.Version=${version}"
  ];

  # The age-only strip's own test gate is Dotfile-Suite/template's
  # dfs-fork-sync workflow, run against Dotfile-Suite/sops directly (see
  # that repo's dfs/README.md) -- go test ./... there covers this exact
  # source. Re-running it here would need network/GnuPG-shaped fixtures
  # that don't apply to a Nix sandbox build; this derivation just needs to
  # produce the binary.
  doCheck = false;

  meta = {
    description = "sops, built age-only from the Dotfile-Suite fork (every other key backend stripped)";
    homepage = "https://github.com/Dotfile-Suite/sops";
    license = lib.licenses.mpl20;
    mainProgram = "sops";
  };
}
