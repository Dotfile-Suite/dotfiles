# CLAUDE.md

Guidance for Claude Code (and any other agent or contributor) working in this
repository. This document sets intentions, not a spec for a finished system —
see [REDESIGN.md](REDESIGN.md) for where the project is headed and
[TODO.md](TODO.md) for known, deferred gaps.

## What this is

A declarative NixOS + home-manager configuration suite ("Dotfile Suite").
It is deliberately generic right now: `hosts/example-{client,server,standalone}`
and `hosts/common/users/example` are templates, not a description of any real
machine. A real deployment copies a template (see `bootstrap.sh`) and
customizes it; nothing personal or hardware-specific belongs in `common/`.

The long-term direction (REDESIGN.md) is a local-first, actor-model computing
suite spanning one machine to many. That vision is aspirational. Don't let it
justify speculative abstraction now — see "Build for what exists" below.

## Repository layout

- `flake.nix` — entry point. Defines `username`/`extraUsers`, the `mkHost`
  builder, and `nixosConfigurations`.
- `hosts/` — per-machine NixOS config.
  - `common/core/` — always-on system modules (nix settings, networking,
    locale, zsh, gnupg, catppuccin).
  - `common/optional/` — opt-in system modules (hyprland, bluetooth,
    virtualisation, wireguard, ...). Never imported by an `example-*` host
    by default; a real host opts in explicitly.
  - `common/users/example/` — parameterized user provisioning (primary
    `username` + `extraUsers`), sops secrets, home-manager wiring.
  - `example-client/`, `example-server/`, `example-standalone/` — minimal
    host skeletons; see each one's own comment for its intended role.
- `home/` — home-manager config, mirroring the same core/optional split.
  - `base.nix` — minimal per-user base (generic CLI/shell core only).
  - `example-*.nix` — per-host entry points, imported once per user on
    that host (see `hosts/common/users/example/default.nix`).
- `bootstrap.sh` — generates `hardware-configuration.nix` on the target
  machine and runs `nixos-install`/`nixos-rebuild switch`. Flakes can't
  shell out to `nixos-generate-config` themselves; this is the documented
  replacement.
- `pkgs/` — custom package derivations (template stub today).
- `.claude/skills/grug/` — invoke for a blunt complexity gut-check.

## Working with the flake

- Format with `nix fmt` (alejandra) before committing.
- Validate with `nix flake check`. Treat a red check like a compiler
  error — fix the cause, don't work around it (`--impure`, deleting the
  failing check, etc.).
- New host: copy an `example-*` directory (or use `bootstrap.sh`), add one
  name to the `nixosConfigurations` list in `flake.nix`, and add a matching
  `home/<name>.nix`. `networking.hostName` derives from the directory name
  automatically — nothing else needs editing for that.
- New user on a host: add the name to `extraUsers` in `flake.nix`.
- Rebuild with `nh os switch`, not raw `nixos-rebuild` — it shows a
  generation diff before applying and keeps GC history sane (see
  `hosts/common/core/nh.nix`).

## Engineering principles

This project wants to be user-friendly *and* well-engineered: stable,
reliable, resilient — not duct tape. The following principles are adapted
from safety-critical software practice (aerospace, automotive, telecom).
Nix is a declarative configuration language, not embedded C, so these are
translated intent, not literal rules to quote at a linter.

**Simple, bounded structure over cleverness.**
(NASA/JPL "Power of Ten": avoid deep recursion and indirection, keep
functions small, use the preprocessor sparingly.) A module should be
readable top to bottom. Prefer a flat `lib.mkOption`-based extension point
(see `hostProfile.*` in `home/common/lib/host-profile.nix`) over a chain of
`lib.mkForce`/override layers. If a file needs a table of contents to
follow, it's grown too much — split it.

**Fail loud, at build time, not at 3am.**
(Power of Ten: assert liberally, check every return value.) Use NixOS
`assertions`/`warnings` and typed `lib.mkOption`s to catch a bad
configuration during `nix flake check`, not during boot. Never default a
missing value to something that "works" wrong — an eval-time error that
names the problem is strictly better than a silent, incorrect fallback.

**One source of truth, narrowest scope.**
(Power of Ten: minimize variable scope. MISRA/ISO 26262: traceability.)
This repo already does this for identity: `username`/`extraUsers` are
defined once in `flake.nix` and threaded through `specialArgs`; nothing
else re-hardcodes a name. Extend that pattern — a value gets one home, not
copies with the hope they stay in sync.

**Everything pinned, every change reviewable.**
(MISRA/ISO 26262: controlled change, no undefined behavior.)
`flake.lock` is committed and *is* the deployed state; upgrade it
deliberately (`nix flake update <input>`), not by accident. `nix flake
check` plus formatting are the equivalent of compiler warnings — address
them, don't suppress them.

**Let it fail cleanly, then recover.**
(Telecom/Erlang-OTP "let it crash," supervision over defensive
programming.) Prefer a service that fails its health check and gets
restarted by systemd over code that tries to paper over inconsistent
state. `nh`'s generation history is the supervision tree at the OS level —
never work in a way that makes a rollback impossible (hand-editing state
outside the declarative config, mutating a generation in place).

**Boring and proven over novel.**
(Telecom's conservatism; grug's "beware fads.") Reach for an existing,
well-trodden NixOS module option before hand-rolling a systemd unit or a
new abstraction. An abstraction earns its place once the same pattern
shows up for real three times — not on the first guess at what might be
needed. This applies to REDESIGN.md's own ambitions too: prove one small
piece works before generalizing it.

**Build for what exists.**
(grug: don't factor too early; force a working demo.) The `hosts/example-*`
skeletons are intentionally bare. Don't add speculative options, roles, or
abstractions to them ahead of a real, working use case — land the concrete
thing first, generalize once a second real host actually needs it.

## Secrets

Managed with sops-nix (see `hosts/common/users/example/default.nix` and
`hosts/common/users/example/secrets/README.md`). Only ever commit
*encrypted* secrets. The committed `secrets/ssh.yaml` is a placeholder and
must be replaced with a real, locally-generated key before actual use — see
that README for the walkthrough. Never commit an age private key or an
unencrypted secret. Broader secrets-management follow-ups are tracked in
`TODO.md`, not solved ad hoc inside unrelated changes.

## Do not

- Hardcode a personal username, hostname, or email into anything under
  `common/` — this repo was deliberately genericized; personal values
  belong only in a real host's own directory, or in `username`/`extraUsers`
  at the flake root.
- Force-push, or hand-edit `flake.lock` — regenerate it with `nix flake
  lock`.
- Bypass `nix flake check`, sandboxing, or the sops encryption boundary to
  unblock a build. Fix the underlying issue instead.
- Add a module or option speculatively "for later." Wait until something
  real needs it (see "Build for what exists").

## Living documents

- [REDESIGN.md](REDESIGN.md) — long-term vision. Aspirational, not a spec
  for the current task.
- [TODO.md](TODO.md) — real, deferred, non-blocking follow-ups. Prune items
  as they're resolved.
