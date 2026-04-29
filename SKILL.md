---
name: mxkey
version: 1.0.0
description: macOS dev-secrets workflow via mxkey (a Keychain wrapper). Use whenever the user handles an API key, token, password, or 2FA backup / recovery code — setting up a new API, running a command that needs a key, editing a .env file, spotting a hardcoded secret in code, or storing single-use recovery codes. Secrets never enter chat, shell history, or plaintext files. macOS only.
tags: [secrets, security, macos, keychain, env]
allowed-tools:
  - Bash
  - Read
  - Edit
---

# mxkey — macOS dev-secrets workflow

Store API keys and tokens in the macOS Keychain so you and agents like Claude, Cursor, or Codex can load them on demand — never pasted into chat, shell history, `.env` files, or source code.

**What this skill does:** wraps the macOS `security` CLI with an `mxkey` command for setting, reading, and injecting secrets into dev commands, plus a `backup` subcommand for single-use 2FA recovery codes. Secrets are named `<category>.<name>` (categories by convention: `api`, `db`, `oauth`, `project`, `infra`, `backup`). Encrypted at rest by the OS Keychain, unlocked by your login password.

**After this skill**, you can run `mxkey run -- <cmd>` to inject secrets into any process, edit `.env` files safely with placeholder refs, and stop worrying about hardcoded keys. macOS only.

## Why Keychain

Every Mac already ships with a secrets vault: the login Keychain. It's
encrypted at rest, unlocked by your login password, access-controlled per
app, and battle-tested for decades. `mxkey` reuses it — adding a naming
convention for dev secrets and a safe way to inject them into commands —
rather than inventing a new storage layer.

## How it works

The core workflow is two commands:

- `mxkey set <name> <ENV_VAR>` — prompts for the value at a hidden terminal
  read, stores it in Keychain.
- `mxkey run <name>... -- <cmd>` — reads the value back and launches
  `<cmd>` with the env var set. The secret lives in that process's memory
  only.

For projects that need several secrets at once, names double as group
prefixes: `mxkey run project.myapp -- pnpm dev` loads every
`project.myapp.*` secret in one call. `mxkey init project.myapp` writes a
`.env.mxkey` manifest in the project root listing those names (no values),
so `mxkey run-here -- pnpm dev` works from any subdirectory.

For high-value keys, `mxkey set --require-auth <name>` stores the secret
with a Keychain ACL that prompts macOS (Touch ID or password) on every
read — useful for production DBs and billing APIs, silent for low-stakes
keys.

Under the hood it's a bash script wrapping `/usr/bin/security`, macOS's
built-in Keychain CLI. `install.sh` installs it by creating one symlink at
`~/.local/bin/mxkey`.

## What happens when the agent uses this skill

With `mxkey` active, the agent will:

- **Migrate `.env` files** into Keychain under `project.<repo>.*` names
  and tell you which keys to trim out of the file.
- **Write `.env.mxkey` manifests** (`mxkey init project.<repo>`) so a
  project has a committable list of which secrets it needs, then wrap dev
  commands with `mxkey run-here -- <cmd>`.
- **Wrap ad-hoc commands** with `mxkey run <name>... -- <cmd>` instead of
  `export FOO=... && cmd` or reading from `.env`.
- **Suggest `--require-auth`** for production DBs, billing APIs, and any
  key where silent theft would hurt — each read triggers a Touch ID / macOS
  password prompt.
- **Flag hardcoded secrets** and `export` lines it spots in source or shell
  rc files, and offer to move them into Keychain.
- **Refuse to echo, store, or commit** secret values pasted into chat — it
  tells you to rotate at the provider and re-save via `mxkey set`.
- **Handle rotation and removal** (`mxkey set` overwrites; `mxkey rm`
  deletes) and remind you to revoke at the provider afterwards.
- **Store 2FA backup / recovery codes** under `backup.<service>.<n>` via
  `mxkey backup add <service>`, with single-use `mxkey backup use <service>`
  consumption (read-then-delete) and require-auth on every read.
- **Ask before running `install.sh`** (the one step that creates the
  `~/.local/bin/mxkey` symlink).

## Scope

Single-user, single-machine. For team-shared secrets, use 1Password,
Doppler, or a vault service; for Linux/Windows, use something else.

## When to activate

Fire on any of these:

- User mentions an API key, token, bearer, client secret, access token, or password
- User says "set up the X API", "add my Y key", "I got a new key for Z"
- User mentions 2FA backup codes, recovery codes, one-time codes, or "I have a list of codes from <provider>"
- User is editing or about to edit a `.env`, `.env.local`, or `.env.*` file
- Agent is writing a command that needs an API key
- Agent sees a hardcoded-looking secret in source files or shell rc files
- User pastes something that looks like a secret (`sk-...`, `gsk_...`, JWT, 30+ char token)

## First-run setup

If `which mxkey` fails, the script is bundled but not on PATH. Run the setup
script once:

```bash
bash "$(dirname "$0")/install.sh"
```

The agent must ask the user before running `install.sh` — it creates a symlink
in `~/.local/bin/`. See `references/setup.md` for details.

**Installing this skill inside a git worktree:** the `mxkey` CLI is a symlink
to the `mxkey` script in this repo. If the skill was installed project-scope
into a disposable worktree (e.g. a Claude Code `.claude/worktrees/...`
session), the symlink breaks when the worktree is removed. Install at user
scope (`~/.claude/skills/mxkey/`) instead so the symlink survives worktree
cleanup.

## Naming convention

`<category>.<name>` — the category prefix keeps things tidy. Pick from:

- `api`     — third-party API keys (`api.openai`, `api.stripe`)
- `db`      — database credentials (`db.prod-postgres`)
- `oauth`   — OAuth client IDs / secrets / refresh tokens (`oauth.google`)
- `project` — project-scoped secrets (`project.myapp.stripe`)
- `infra`   — infra credentials (`infra.aws-deploy`)
- `backup`  — single-use 2FA recovery codes, indexed (`backup.github.1`,
  `backup.porkbun.2`). Managed via the `mxkey backup` subcommand, not
  `mxkey set` directly.

The env var name is uppercase (`OPENAI_API_KEY`, `STRIPE_SECRET_KEY`). For
backup codes the env var is auto-generated as `<SERVICE>_BACKUP_<N>`.

## Command cheatsheet

| Command | What it does |
| --- | --- |
| `mxkey set [--require-auth] <name> <ENV_VAR>` | Save a secret (hidden prompt). `--require-auth` triggers a macOS / Touch ID prompt on every read. |
| `mxkey run <name>... -- <cmd>` | Run `<cmd>` with the named secrets loaded as env vars. A name with no exact match is a group prefix. |
| `mxkey init <group-prefix>` | Write `.env.mxkey` in the current folder listing every matching name (values stay in Keychain). |
| `mxkey run-here -- <cmd>` | Walk up to find `.env.mxkey`, run `<cmd>` with every listed secret loaded. |
| `mxkey migrate <path-to-.env> [project-slug]` | Read a `.env` file and import every key into Keychain under `project.<slug>.*`. Values are piped via stdin so they never touch disk or shell history. |
| `mxkey list [prefix]` | Show stored names, optionally filtered. |
| `mxkey rm <name>` | Delete a secret from Keychain. |
| `mxkey get` / `mxkey export` | Print a value / `ENV_VAR=value`. Escape hatches — prefer `run`. |
| `mxkey backup add [--show] <service>` | Add 2FA recovery codes one per line at a prompt (hidden by default; `--show` echoes input). Stored under `backup.<service>.<n>`, always require-auth. |
| `mxkey backup use <service>` | Print and atomically delete the next backup code for a service (single-use consumption). |
| `mxkey backup list [service]` | Show how many backup codes remain (no values). |
| `mxkey backup rm <service>` | Delete every backup code for a service. |

## Agent playbooks

### Detecting `.env` files

When the agent encounters a `.env`, `.env.local`, or similar in a project:

1. Offer to migrate: "I can move these N keys into mxkey under `project.<repo>.*`."
2. On approval, run `mxkey migrate <path-to-env> <repo>`.
3. Offer to add `.env*` to `.gitignore`.
4. After a successful migration, **trim the migrated keys out of `.env`**.
   The command prints the exact list at the end — remove those lines (or the
   whole file if nothing non-secret remains). Leaving both copies means
   secrets still exist in plaintext and the two stores can drift.
5. Suggest wrapping dev commands: `mxkey run project.<repo> -- <cmd>`, or
   regenerating the `.env` on demand from `mxkey export`.

Don't migrate silently — some `.env` files are loaded by tooling that can't
read env vars from the parent process. Ask first.

Full walkthrough: `references/migrate-from-env.md`.

### Detecting `export KEY=` in shell rc files

If the agent is reading or editing `~/.zshrc`, `~/.bashrc`, `~/.profile`, a
`direnv` `.envrc`, etc. and sees `export SOMETHING_API_KEY=...`:

1. Flag it: "I see a secret exported in your shell rc. That leaks into every
   process you spawn."
2. Offer to migrate: move the value into mxkey, remove the `export` line, wrap
   the consuming command(s) in `mxkey run`.

Mention it once per session — don't nag.

### Detecting hardcoded secrets in code

If the agent sees a hardcoded-looking secret in source files (e.g.
`Authorization: Bearer xyz`, `const API_KEY = "..."`, `apiKey: "sk-..."`):

1. Warn before suggesting or writing a commit.
2. Suggest the `mxkey run` + `process.env.FOO_API_KEY` pattern instead.

### Rotating a secret

1. User generates a new key at the provider.
2. Run `mxkey set <name> <ENV_VAR>` again — overwrites the stored value.
3. Remind the user to revoke the old key at the provider.

### Removing a secret

1. Confirm with `mxkey list` which name to remove.
2. Run `mxkey rm <name>`.
3. Remind the user: **the key is still valid at the provider** until they
   revoke it there.

### Storing 2FA backup / recovery codes

When the user mentions backup codes, recovery codes, one-time codes, or has
just generated a list of them at a provider (GitHub, Google, Porkbun,
1Password, etc.):

1. Suggest `mxkey backup add <service>` — service name is a single word, no
   dots (e.g. `github`, `google`, `porkbun`).
2. Default is hidden input. Mention `--show` if the user wants to see what
   they paste — but warn that visible input lands in terminal scrollback
   and tmux/screen buffers, so a fresh window or `clear` afterward is
   wise.
3. Each code is stored as `backup.<service>.<n>` with require-auth (Touch
   ID on every read) — no opt-out, recovery codes always need the prompt.
4. To consume one later: `mxkey backup use <service>` prints the next code
   and atomically deletes it (single-use). Never use `mxkey get`/`export`
   on a backup code — that doesn't delete it and you'll re-use a burned
   code.
5. `mxkey backup list` shows remaining counts across all services; `mxkey
   backup list <service>` for one. Remind the user to regenerate at the
   provider when the count gets low.

Don't migrate backup codes silently — confirm the service name first, and
if there's already a `backup.<service>.*` group, ask before adding (the
new codes append; old codes stay unless the user runs `mxkey backup rm`).

### Refusing a pasted secret

If the user pastes something that looks like a secret into chat:

1. **Do not** act on it. **Do not** store it. **Do not** echo it back.
2. Tell the user: "That looks like a secret. Because it's now in this
   conversation, rotate it at the provider, then run `mxkey set <name> <ENV_VAR>`
   and type the new value at the hidden prompt."

## Hard rules

- NEVER echo a secret value in a response
- NEVER write a secret to a file in plaintext
- NEVER commit a secret, the `~/.config/mxkey/index` file (if tracked), or any backup dump
- NEVER ask the user to paste a secret into chat — always use `mxkey set`'s hidden prompt
- NEVER set long-lived bearer tokens via `export FOO=...` in shell rc files — defeats the point
- NEVER use `mxkey get` where `mxkey run` works
- If the user pastes a secret by mistake: refuse, warn, tell them to rotate

## Troubleshooting

See `references/troubleshooting.md` for:
- Repeated Keychain GUI prompts
- `~/.local/bin` not on PATH
- "not in index" errors
- Reconciling Keychain entries with the on-disk index

## Further reading

`references/keychain-deep-dive.md` — how `mxkey` wraps `/usr/bin/security`,
why the on-disk index exists, the `-T /usr/bin/security` ACL flag, and how
`mxkey run` injects env vars via `exec`.
