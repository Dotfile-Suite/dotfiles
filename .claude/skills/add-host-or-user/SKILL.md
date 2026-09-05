---
name: add-host-or-user
description: Steps to add a new NixOS host or add a user to an existing host in this flake.
---

- New host: copy an `example-*` directory (or use `bootstrap.sh`), add one
  name to the `nixosConfigurations` list in `flake.nix`, and add a matching
  `home/<name>.nix`. `networking.hostName` derives from the directory name
  automatically — nothing else needs editing for that.
- New user on a host: add the name to `extraUsers` in `flake.nix`.
