# User secrets

Every user declared in `flake.nix` (the primary `username`, plus each name in
`extraUsers`) needs a `<username>.yaml` file here, sops-encrypted, holding
that person's SSH identity and git commit identity. `hosts/common/secrets/
default.nix` is the module that wires a `<username>.yaml` into that user's
account (see its own comments); this file is about *populating* that YAML.

## Automated: `bootstrap.sh`

The normal path is to just run `./bootstrap.sh <host>` (see the script's own
`--help`). Before touching hardware config or installing/switching, it:

1. Asks the flake for the real user list (`nix eval --json .#users`).
2. For each user missing a `hosts/common/secrets/<user>.yaml`, generates a
   fresh Ed25519 keypair, fills in a placeholder git identity, encrypts it,
   and `git add`s it.
3. Prints the new public key and a reminder to register it (GitHub, or
   `authorized_keys` on any server you want to reach with it) and to replace
   the placeholder identity: `sops edit hosts/common/secrets/<user>.yaml`.

A user who already has a `<user>.yaml` is left alone.

To supply an existing key instead of generating one, or to rotate a user's
key, pass `--key-<user>=<path-to-private-key>`:

```sh
./bootstrap.sh my-desktop --key-alice=/path/to/alice_id_ed25519
```

This only replaces the SSH key; an already-set git identity (edited via
`sops edit`) is preserved across a rotation.

## Manual

If you'd rather not use bootstrap.sh, or need to edit a field directly:

1. Generate a fresh Ed25519 keypair **locally**, not on a shared/remote
   machine:

   ```sh
   ssh-keygen -t ed25519 -a 100 -C "<username>@<host>" -f /tmp/id_ed25519 -N ""
   ```

2. Write it into the secret non-interactively -- pasting into `sops edit`'s
   editor is easy to get wrong (e.g. vim's autoindent silently corrupting a
   pasted multi-line key), so prefer building the file directly. Each user's
   file holds two block-scalar keys, `id_ed25519` and `git_identity`:

   ```sh
   {
     echo "id_ed25519: |"
     sed 's/^/  /' /tmp/id_ed25519
     echo "git_identity: |"
     printf '[user]\n\tname = Real Name\n\temail = real@email.example\n' | sed 's/^/  /'
   } > /tmp/secret-plain.yaml
   mv /tmp/secret-plain.yaml hosts/common/secrets/<username>.yaml
   sops encrypt --in-place hosts/common/secrets/<username>.yaml
   ```

   (`sops edit hosts/common/secrets/<username>.yaml` also works for editing
   an existing file interactively -- just make sure your editor isn't
   reindenting pasted text. Editing this way is how you replace the
   placeholder `git_identity` after bootstrap.sh generates one.)

3. Register `/tmp/id_ed25519.pub` (the **public** key) with GitHub under
   Settings > SSH and GPG keys, and with `authorized_keys` on any servers
   you want to reach with it.

4. Delete both `/tmp/id_ed25519*` files.

5. **`git add hosts/common/secrets/<username>.yaml`.** Nix flakes evaluate
   the git-tracked snapshot of the repo, not the raw working tree -- an
   unstaged secrets file is invisible to `nix flake check` and
   `nixos-rebuild switch --flake`, even though it exists on disk. Skipping
   this step makes the build fail with the same "missing secrets" error as
   if the file didn't exist at all.

## What ends up where

After a rebuild, `hosts/common/secrets/default.nix` decrypts, per user:

- `id_ed25519` to `~/.ssh/id_ed25519` (mode `0400`), used as the default SSH
  identity for every connection -- see `home/common/core/cli/ssh.nix`. A
  oneshot systemd service derives `~/.ssh/id_ed25519.pub` from it
  automatically on every activation and whenever the key changes, so there's
  no manual `ssh-keygen -y` step and no risk of a stale `.pub` sibling
  overriding the real key.
- `git_identity` to `~/.config/git/identity.gitconfig` (mode `0400`), a
  ready-made `[user]` block that `home/common/core/cli/git.nix` includes into
  that user's `.gitconfig` -- so every user gets their own commit name/email
  instead of one shared identity.

If a user declared in `flake.nix` doesn't have a matching `<username>.yaml`
here, the build fails at evaluation time with a clear message naming the
missing file, rather than a cryptic sops error partway through activation.
