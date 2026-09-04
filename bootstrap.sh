#!/usr/bin/env bash
# Stand up or refresh a host in this flake, without hand-writing
# hardware-configuration.nix.
#
# Nix flakes evaluate purely, so this repo can't shell out to
# nixos-generate-config on its own -- this script is that missing step. It
# runs `nixos-generate-config --show-hardware-config` on the *target*
# machine and writes the result straight into hosts/<host>/hardware-
# configuration.nix, replacing the generic placeholder there (see that
# file's own comment) with the real disk/kernel-module layout for this
# specific machine.
#
# Usage:
#   ./bootstrap.sh <host> [--from <template>] [--root <path>]
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
set -euo pipefail

usage() {
  sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
host=""
template=""
root=""
mode="switch" # switch | install | skip-build

while [ $# -gt 0 ]; do
  case "$1" in
    --from) template="$2"; shift 2 ;;
    --root) root="$2"; shift 2 ;;
    --install) mode="install"; shift ;;
    --switch) mode="switch"; shift ;;
    --skip-build) mode="skip-build"; shift ;;
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

  template_home="$repo_root/home/$template.nix"
  if [ -f "$template_home" ] && [ ! -f "$home_file" ]; then
    echo "==> Scaffolding home/$host.nix from home/$template.nix"
    cp "$template_home" "$home_file"
  fi
fi

if [ ! -f "$home_file" ]; then
  echo "Warning: home/$host.nix doesn't exist. hosts/common/users/example imports" \
       "home/\${networking.hostName}.nix, so the build will fail without it." >&2
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
