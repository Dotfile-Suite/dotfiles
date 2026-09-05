#!/usr/bin/env bash
# Stand up or refresh a host in this flake: hardware-configuration.nix and
# per-user secrets, neither of which a pure flake evaluation can produce on
# its own.
#
# Nix flakes evaluate purely, so this repo can't shell out to
# nixos-generate-config on its own -- this script is that missing step. It
# runs `nixos-generate-config --show-hardware-config` on the *target*
# machine and writes the result straight into hosts/<host>/hardware-
# configuration.nix, replacing the generic placeholder there (see that
# file's own comment) with the real disk/kernel-module layout for this
# specific machine.
#
# It also ensures every user configured in flake.nix (`username` and each
# name in `extraUsers`) has a hosts/common/secrets/<user>.yaml, generating a
# fresh SSH keypair and a placeholder git identity for anyone missing one.
# See hosts/common/secrets/README.md for what ends up where.
#
# Usage:
#   ./bootstrap.sh <host> [--from <template>] [--root <path>]
#                         [--key-<user>=<path>]... [--skip-secrets]
#                         [--install | --switch | --skip-build]
#
# Examples:
#   # Brand-new machine, from a NixOS live ISO with the target mounted at /mnt
#   sudo ./bootstrap.sh my-desktop --from example-standalone --root /mnt --install
#
#   # Point an already-installed NixOS machine at a new host in this flake
#   sudo ./bootstrap.sh my-desktop --from example-client --switch
#
#   # Re-detect hardware for a host that already exists (e.g. after a disk
#   # change), without installing or switching
#   sudo ./bootstrap.sh my-desktop --skip-build
#
#   # Supply alice's existing key instead of generating one, or rotate it
#   ./bootstrap.sh my-desktop --key-alice=/path/to/alice_id_ed25519 --skip-build
set -euo pipefail

usage() {
  sed -n '2,36p' "$0" | sed 's/^# \{0,1\}//'
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
host=""
template=""
root=""
mode="switch" # switch | install | skip-build
skip_secrets=0
declare -A key_overrides=()

while [ $# -gt 0 ]; do
  case "$1" in
    --from) template="$2"; shift 2 ;;
    --root) root="$2"; shift 2 ;;
    --install) mode="install"; shift ;;
    --switch) mode="switch"; shift ;;
    --skip-build) mode="skip-build"; shift ;;
    --skip-secrets) skip_secrets=1; shift ;;
    --key-*)
      rest="${1#--key-}"
      if [[ "$rest" != *=* ]]; then
        echo "Malformed flag (expected --key-<user>=<path>): $1" >&2
        exit 1
      fi
      key_overrides["${rest%%=*}"]="${rest#*=}"
      shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    *)
      if [ -n "$host" ]; then
        echo "Only one host may be given (got '$host' and '$1')." >&2
        exit 1
      fi
      host="$1"; shift ;;
  esac
done

if [ -z "$host" ]; then
  usage
  exit 1
fi

host_dir="$repo_root/hosts/$host"
home_file="$repo_root/home/$host.nix"

if [ ! -d "$host_dir" ]; then
  if [ -z "$template" ]; then
    echo "hosts/$host doesn't exist yet -- pass --from <template> to scaffold it" \
         "(e.g. --from example-client, --from example-server, --from example-standalone)." >&2
    exit 1
  fi
  template_dir="$repo_root/hosts/$template"
  if [ ! -d "$template_dir" ]; then
    echo "Template hosts/$template doesn't exist." >&2
    exit 1
  fi

  echo "==> Scaffolding hosts/$host from hosts/$template"
  cp -r "$template_dir" "$host_dir"
  # networking.hostName in every example-* host is derived from the
  # directory name (see hosts/example-*/default.nix), so nothing in
  # default.nix needs editing here -- it's already correct for $host.
  # Nix flakes evaluate the git-tracked snapshot of the repo, not the raw
  # working tree, so this (and everything else this script writes) needs
  # to be staged or it's invisible to `nix flake check`/`--flake` builds.
  git -C "$repo_root" add "$host_dir"

  template_home="$repo_root/home/$template.nix"
  if [ -f "$template_home" ] && [ ! -f "$home_file" ]; then
    echo "==> Scaffolding home/$host.nix from home/$template.nix"
    cp "$template_home" "$home_file"
    git -C "$repo_root" add "$home_file"
  fi
fi

if [ ! -f "$home_file" ]; then
  echo "Warning: home/$host.nix doesn't exist. hosts/common/users/example imports" \
       "home/\${networking.hostName}.nix, so the build will fail without it." >&2
fi

if [ "$skip_secrets" -ne 1 ]; then
  echo "==> Ensuring per-user secrets in hosts/common/secrets/"
  secrets_dir="$repo_root/hosts/common/secrets"

  command -v nix >/dev/null 2>&1 || {
    echo "nix is required to look up flake.nix's user list (.#users)." >&2
    exit 1
  }

  users_json="$(nix eval --json --no-warn-dirty "$repo_root#users")" || {
    echo "Failed to evaluate $repo_root#users -- is flake.nix valid?" >&2
    exit 1
  }
  mapfile -t all_users < <(printf '%s' "$users_json" | tr -d '[]"' | tr ',' '\n')

  for ku in "${!key_overrides[@]}"; do
    found=0
    for u in "${all_users[@]}"; do
      if [ "$u" = "$ku" ]; then
        found=1
        break
      fi
    done
    if [ "$found" -ne 1 ]; then
      echo "--key-$ku=... given, but '$ku' isn't in flake.nix's username/extraUsers." >&2
      exit 1
    fi
    if [ ! -f "${key_overrides[$ku]}" ]; then
      echo "--key-$ku=${key_overrides[$ku]}: no such file." >&2
      exit 1
    fi
  done

  require_sops() {
    command -v sops >/dev/null 2>&1 || {
      echo "sops is required to manage hosts/common/secrets/*.yaml." >&2
      echo "Try: nix shell $repo_root#myPkgs.x86_64-linux.dfs-sops (or nixpkgs#sops)" >&2
      exit 1
    }
  }

  # Pulls the existing git_identity block back out of an already-encrypted
  # file, so rotating a key with --key-<user>=<path> doesn't clobber an
  # identity someone already set for real via `sops edit`.
  extract_git_identity() {
    sops decrypt "$1" | awk '
      /^git_identity:/ { capture=1; next }
      /^[^ ]/          { capture=0 }
      capture          { sub(/^  /, ""); print }
    '
  }

  ensure_user_secret() {
    local name="$1"
    local file="$secrets_dir/$name.yaml"
    local override="${key_overrides[$name]:-}"

    if [ -z "$override" ] && [ -f "$file" ]; then
      echo "==> $name: hosts/common/secrets/$name.yaml already exists, leaving it alone."
      return 0
    fi

    require_sops
    local keysrc="$override" tmp_key_dir=""
    if [ -z "$keysrc" ]; then
      tmp_key_dir="$(mktemp -d)"
      ssh-keygen -t ed25519 -a 100 -C "${name}@dotfiles" \
        -f "$tmp_key_dir/id_ed25519" -N "" -q
      keysrc="$tmp_key_dir/id_ed25519"
    fi

    local git_identity
    if [ -f "$file" ]; then
      git_identity="$(extract_git_identity "$file")"
    else
      git_identity="$(printf '[user]\n\tname = %s\n\temail = %s\n' \
        "$name" "${name}@example.invalid")"
    fi

    local plain
    plain="$(mktemp)"
    {
      echo "id_ed25519: |"
      sed 's/^/  /' "$keysrc"
      echo "git_identity: |"
      printf '%s\n' "$git_identity" | sed 's/^/  /'
    } > "$plain"
    mv "$plain" "$file"
    sops encrypt --in-place "$file"
    git -C "$repo_root" add "$file"

    if [ -n "$override" ]; then
      echo "==> $name: SSH key replaced from $override (git identity preserved)."
    else
      echo "==> $name: generated new SSH key. Public key (register with"
      echo "    GitHub / authorized_keys):"
      sed 's/^/    /' "$tmp_key_dir/id_ed25519.pub"
      echo "    Git identity is a placeholder -- run: sops edit $file"
    fi
    if [ -n "$tmp_key_dir" ]; then
      rm -rf "$tmp_key_dir"
    fi
  }

  for u in "${all_users[@]}"; do
    if [ -n "$u" ]; then
      ensure_user_secret "$u"
    fi
  done
fi

if [ "$(id -u)" -ne 0 ]; then
  echo "nixos-generate-config needs root -- re-run with sudo." >&2
  exit 1
fi

root_args=()
if [ -n "$root" ]; then
  root_args=(--root "$root")
fi

echo "==> Generating hosts/$host/hardware-configuration.nix"
nixos-generate-config "${root_args[@]}" --show-hardware-config > "$host_dir/hardware-configuration.nix"
git -C "$repo_root" add "$host_dir/hardware-configuration.nix"

case "$mode" in
  install)
    echo "==> nixos-install --flake $repo_root#$host"
    nixos-install "${root_args[@]}" --flake "$repo_root#$host"
    ;;
  switch)
    echo "==> nixos-rebuild switch --flake $repo_root#$host"
    nixos-rebuild switch --flake "$repo_root#$host"
    ;;
  skip-build)
    echo "==> Skipping install/switch (--skip-build). hosts/$host/hardware-configuration.nix is up to date."
    ;;
esac
