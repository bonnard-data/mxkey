# Setup reference

## What `install.sh` does

1. Checks the OS is macOS. Bails otherwise.
2. Resolves the bundled `mxkey` script (at `<repo-dir>/mxkey`).
3. Makes it executable (the tarball unpack may drop the `+x` bit).
4. Checks if `mxkey` is already on PATH. If so, exits without changes.
5. Ensures `~/.local/bin/` exists; creates it if not.
6. Creates a symlink: `~/.local/bin/mxkey` → `<repo-dir>/mxkey`.
7. Verifies `~/.local/bin/` is on PATH. Prints a `PATH` fix snippet if not.
8. Runs `mxkey list` as a sanity check.

The script is **idempotent** — safe to re-run any time.

## Why a symlink (not a copy)

When the skill updates (e.g. you `git pull` the repo), the script at
`<repo-dir>/mxkey` gets replaced. The symlink in `~/.local/bin/` automatically
points at the new version — no re-setup needed.

A copy would require re-running setup after every skill update to pick up
changes.

## Verifying the setup

```bash
which mxkey                      # should print ~/.local/bin/mxkey
ls -la ~/.local/bin/mxkey        # should show the symlink target
mxkey list                       # should print "(no secrets stored)" on a fresh install
```

## Uninstalling

Just delete the symlink. Skill data and Keychain entries are not affected:

```bash
rm ~/.local/bin/mxkey
```

To also wipe all stored secrets:

```bash
# Remove the on-disk index
rm -rf ~/.config/mxkey

# Remove the Keychain entries (nuclear option — affects ALL mxkey secrets)
security dump-keychain login.keychain-db 2>/dev/null \
  | grep -oE 'mxkey\.[^"]+' \
  | sort -u \
  | while read -r svc; do
      security delete-generic-password -s "$svc" >/dev/null 2>&1 || true
    done
```

## PATH troubleshooting

If `~/.local/bin/` isn't on PATH, add this to the top of your shell rc:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

- zsh users: `~/.zshrc`
- bash users: `~/.bashrc` (or `~/.bash_profile` for login shells on macOS)
- fish users: `set -U fish_user_paths $HOME/.local/bin $fish_user_paths`

Then reload: `source ~/.zshrc` (or equivalent).
