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

## About

mxkey is part of the Sherpi skill catalog by [Bonnard](https://bonnard.dev). Built for developers and AI agents handling secrets.

## License

MIT
