# mxkey

Store API keys, tokens, and 2FA recovery codes in the macOS Keychain. Inject them into commands without ever typing them, copying them into `.env` files, or pasting them into your shell.

```bash
mxkey set api.openai OPENAI_API_KEY            # save (hidden prompt)
mxkey run api.openai -- curl https://api.openai.com/v1/models    # use
```

Secrets stay encrypted at rest in the macOS Keychain, unlocked by your login password. They never enter shell history, plaintext files, or process arguments.

macOS only. Single bash script, no dependencies beyond what ships with macOS.

## Install

```bash
git clone https://github.com/bonnard-data/mxkey.git
cd mxkey
bash install.sh
```

This symlinks `mxkey` into `~/.local/bin/`. Make sure that's on your `PATH`.

## Documentation

- [`SKILL.md`](./SKILL.md) — agent skill definition (for Claude Code, Cursor, etc.)
- [`references/setup.md`](./references/setup.md) — install details, uninstall, PATH troubleshooting
- [`references/migrate-from-env.md`](./references/migrate-from-env.md) — moving an existing `.env` file into mxkey
- [`references/troubleshooting.md`](./references/troubleshooting.md) — common errors
- [`references/keychain-deep-dive.md`](./references/keychain-deep-dive.md) — how mxkey wraps the macOS `security` CLI

## Security model

Secrets are stored as macOS Keychain "generic password" entries — encrypted at rest, unlocked by your login password, scoped to your user. Only your user UID can read them. mxkey wraps the `security` CLI that ships with macOS; it doesn't invent its own crypto.

**What mxkey protects against:** plaintext leaks via `.env` files in git, shell history, `export` in rc files, screen-shares, log capture, and credential exfil from compromised dev tools that read `.env` paths.

**What mxkey doesn't protect against:** an attacker already running as your user. They can read your Keychain directly. There is also a short, millisecond-scale window where a secret appears in process argv during `mxkey run` and `mxkey set` — observable by a same-UID attacker running `ps aww` in a tight loop. See [`references/keychain-deep-dive.md`](./references/keychain-deep-dive.md) for the full breakdown.

For high-value secrets (production DBs, billing APIs), use `mxkey set --require-auth <name>` — every read triggers a macOS confirmation prompt (Touch ID on eligible Macs).

## About

mxkey is part of the Sherpi skill catalog by [Bonnard](https://bonnard.dev). Built for developers and AI agents handling secrets.

## License

MIT
