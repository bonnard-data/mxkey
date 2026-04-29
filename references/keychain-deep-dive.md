# How mxkey actually works

For users who want to understand what's happening under the hood.

## The three layers

```
Your terminal / agent
     │
     ▼
mxkey (single bash script)
     │
     ▼
/usr/bin/security (macOS CLI, ships with the OS)
     │
     ▼
macOS Keychain (encrypted database, scoped to your login)
```

mxkey is a thin wrapper. Every secret operation ultimately hits the same
`security` CLI you could use yourself — mxkey adds a naming convention, an
env-var mapping, and safe injection via `exec`.

## Storage model

Each secret is stored as a Keychain "generic password" entry with three fields:

| Field | What mxkey puts there                        |
| ----- | -------------------------------------------- |
| `service` | `mxkey.<category>.<name>` (e.g. `mxkey.api.openai`) |
| `account` | the env var name (e.g. `OPENAI_API_KEY`)   |
| `password` | the secret value itself                    |

The `mxkey.*` service prefix creates a private namespace — it won't collide
with WiFi passwords, Safari logins, Slack tokens, or any other Keychain
entries.

## The on-disk index

`~/.config/mxkey/index` is a plain tab-separated file:

```
api.openai    OPENAI_API_KEY
api.stripe    STRIPE_SECRET_KEY
project.myapp.database_url    DATABASE_URL
```

**It contains no secret values.** It exists for two reasons:

1. **`mxkey list`** needs to enumerate what's stored without parsing the
   massive `security dump-keychain` output.
2. **`mxkey run <name> -- <cmd>`** needs to know which env var to inject —
   Keychain stores the `account` field but querying it back out by service
   name requires an extra lookup round-trip.

Losing the index doesn't lose secrets (they're still in Keychain). Losing
Keychain doesn't lose the index (it's just a names list). They can be
reconciled if one drifts from the other.

## How `mxkey run` injects a secret safely

The single most important operation. Here's the code path, simplified:

```bash
# 1. Look up the env var name from the index
envvar=$(awk -F'\t' -v n="api.openai" '$1==n {print $2}' ~/.config/mxkey/index)
# envvar is now "OPENAI_API_KEY"

# 2. Pull the secret out of Keychain
val=$(security find-generic-password -s mxkey.api.openai -w)
# val is now the actual secret, in this shell's memory

# 3. exec replaces mxkey's process with the target command,
#    passing the env var via /usr/bin/env
exec /usr/bin/env "$envvar=$val" curl ...
```

**Why this is safe:**

- Secret values are never written to disk, never go through a temp file,
  and never land in shell history.
- `exec` replaces mxkey's own process — the child owns the env; mxkey
  doesn't linger holding a copy.
- Once the child exits, its env is released with the process. No cleanup
  needed.
- Env vars are only readable by processes with the same user ID (and on
  macOS even that's restricted by sandboxing for most apps).

**What's not safe (and why mxkey can't fix it):**

There is a brief, millisecond-scale window where the secret is visible in
process argv to anything that can call `ps aww` as the same user:

- `security add-generic-password -w <secret> ...` on **write** — macOS's
  `security` CLI requires the password as a command-line argument; there
  is no stdin-fed alternative for `add-generic-password`.
- `/usr/bin/env KEY=<secret> <cmd>` during `mxkey run` — `env` sets vars
  from its own argv, then `exec`s the child. After the `exec` the secret
  is in the child's env (not argv), but the `env` process itself briefly
  had it on the command line.

Both windows are short (exec happens immediately after argv parsing), but
a same-UID attacker running `ps aww` in a tight loop could catch them. If
you're modelling against a co-located attacker who's already running as
your user, they can also read Keychain directly, so this isn't the weakest
link — but it's worth being honest about. The earlier phrasing "never in
arguments" was overclaiming; this is the accurate picture.

## The `-T /usr/bin/security` flag

When mxkey calls `security add-generic-password`, it passes `-T /usr/bin/security`.
This modifies the Keychain entry's ACL so that the `security` CLI itself is
pre-authorized to read the entry without a GUI prompt.

Without this flag, every `mxkey run` would pop a "allow access?" dialog — fine
for interactive use, unusable for scripts or cron jobs.

Other apps (your browser, third-party apps) still need to prompt and get
explicit user approval. Only the `security` binary is whitelisted.

## Compared to alternatives

| Approach | Leak risk | Portability | Encryption | Session scope |
| -------- | --------- | ----------- | ---------- | ------------- |
| Plaintext `.env` file | High (git, backups, logs) | Full | None | File-lifetime |
| `export KEY=...` in `~/.zshrc` | Medium (every child process sees it) | Shell-only | None | Shell-lifetime |
| `.envrc` + direnv | Medium | Shell + direnv-aware tools | None | Shell-lifetime |
| 1Password / Bitwarden CLI | Low | Cross-platform | Yes (vendor) | Session-based |
| **mxkey** | Low | macOS-only | Yes (Keychain + login password) | Per-command |

mxkey's tradeoff: macOS-locked, single-machine, but zero dependencies, zero
subscription, and tighter scoping than most alternatives.

## What `security` can do that mxkey doesn't expose

`security` has ~40 subcommands. mxkey only uses:

- `add-generic-password` (for `set`)
- `find-generic-password` (for `get`, `run`, `export`)
- `delete-generic-password` (for `rm`)

If you want to poke around manually:

```bash
man security
security help | less
security dump-keychain login.keychain-db   # huge; pipe to grep
```
