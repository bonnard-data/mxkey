# Troubleshooting

## `mxkey: command not found`

`~/.local/bin/` isn't on PATH, or the symlink wasn't created. Fix:

```bash
bash ~/.claude/skills/mxkey/install.sh
```

(Or whichever editor's skills dir the bundle landed in —
`.cursor/skills/mxkey/`, `.agents/skills/mxkey/`, etc.)

Then restart your terminal or `source ~/.zshrc`.

## `error: <name> not in index (try: mxkey list)`

The on-disk index at `~/.config/mxkey/index` doesn't have an entry for this
name. Either:

- You typed a wrong name → check `mxkey list` for the exact spelling.
- The index was deleted/corrupted but Keychain still has the entry.

To rebuild a missing index entry, re-run `mxkey set` with the original name
and env var — the value is prompted fresh, but the Keychain already has it, so
you could alternatively pull the value yourself and pipe it in:

```bash
security find-generic-password -s mxkey.api.openai -w \
  | mxkey set api.openai OPENAI_API_KEY
```

## `error: <service> not found in keychain`

The opposite problem — the index has an entry but Keychain doesn't. Likely
because the Keychain entry was deleted manually (via Keychain Access.app) or
on another machine.

Fix by re-setting:

```bash
mxkey set api.openai OPENAI_API_KEY
```

## Repeated macOS GUI prompts on every read

When you run `mxkey run` (or `mxkey get`), macOS pops a "allow access?" dialog
every single time. This means the Keychain entry's ACL doesn't include the
`security` binary as an allowed caller.

`mxkey set` uses the `-T /usr/bin/security` flag which should prevent this on
new entries. If you're seeing prompts on old entries:

```bash
# Re-save the entry with the correct ACL
mxkey set <name> <ENV_VAR>   # enter the value again at the hidden prompt
```

## "Always allow" button doesn't appear, or doesn't stick

Sometimes the dialog only shows "Allow" and "Deny" — not "Always Allow". This
is the default when `-T` wasn't set during creation. Delete and re-add:

```bash
security delete-generic-password -s mxkey.api.openai
mxkey set api.openai OPENAI_API_KEY
```

## I want to see what's really in Keychain

```bash
# All mxkey entries
security dump-keychain login.keychain-db | grep -A1 '"mxkey\.'

# One specific entry's metadata (but not value)
security find-generic-password -s mxkey.api.openai
```

## I accidentally committed the `~/.config/mxkey/index` file

It doesn't contain values — only `name <TAB> env_var_name` pairs. Not a
secret, but still a metadata leak (tells someone which APIs you use). To
untrack without deleting:

```bash
git rm --cached ~/.config/mxkey/index
echo 'mxkey-index' >> .gitignore
git commit -m "untrack mxkey index"
```

(Your index shouldn't be in a repo in the first place — it's in your home
dir, not the project. But some over-eager backup rsync configs or dotfile
repos might catch it.)

## Something weird: `mxkey set` hangs

Probably you piped something into it by accident and it's waiting for stdin.
Ctrl-C, then re-run as a normal interactive call:

```bash
mxkey set api.openai OPENAI_API_KEY
# (type value at hidden prompt)
```
