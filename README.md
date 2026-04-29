<p align="center">
  <a href="https://mxkey.space">
    <img src="./assets/icon.png" alt="mxkey" width="120" height="120" />
  </a>
</p>

<h1 align="center">mxkey</h1>

<p align="center">
  <strong>Agent-native macOS Keychain CLI for dev secrets.</strong><br />
  Never in <code>.env</code> files. Never in shell history. Never in chat.
</p>

<p align="center">
  <a href="https://github.com/bonnard-data/mxkey/releases/latest"><img src="https://img.shields.io/github/v/release/bonnard-data/mxkey?style=flat-square&color=66C430&label=release" alt="latest release" /></a>
  <a href="https://github.com/bonnard-data/mxkey/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-66C430?style=flat-square" alt="MIT License" /></a>
  <img src="https://img.shields.io/badge/platform-macOS-66C430?style=flat-square" alt="macOS only" />
  <a href="https://github.com/bonnard-data/homebrew-mxkey"><img src="https://img.shields.io/badge/homebrew-tap-66C430?style=flat-square" alt="Homebrew tap" /></a>
  <a href="https://docs.mxkey.space/docs"><img src="https://img.shields.io/badge/docs-mxkey.space-66C430?style=flat-square" alt="Docs" /></a>
</p>

<p align="center">
  <a href="https://mxkey.space">Website</a> ·
  <a href="https://docs.mxkey.space/docs">Docs</a> ·
  <a href="https://github.com/bonnard-data/mxkey/releases">Releases</a> ·
  <a href="https://github.com/bonnard-data/homebrew-mxkey">Homebrew tap</a>
</p>

---

## What is mxkey?

`mxkey` is a single bash script that wraps the macOS Keychain — the encrypted vault that already ships with your Mac — into a developer-friendly CLI. Save API keys, tokens, and 2FA recovery codes once, then inject them into commands as environment variables. The values never enter `.env` files, shell history, or any chat conversation.

```bash
mxkey set api.openai OPENAI_API_KEY                              # save (hidden prompt)
mxkey run api.openai -- curl https://api.openai.com/v1/models    # use
```

Secrets stay encrypted at rest in macOS Keychain, unlocked by your login password. macOS only. No dependencies beyond what ships with the OS.

## Install

```bash
brew install bonnard-data/mxkey/mxkey
```

The single-line form combines `brew tap` and `brew install`. Updates land via `brew upgrade mxkey`. Or build from source:

```bash
git clone https://github.com/bonnard-data/mxkey.git
cd mxkey
bash install.sh
```

## Quickstart

```bash
mxkey set api.openai OPENAI_API_KEY                  # save a secret
mxkey run api.openai -- curl https://api.openai.com/v1/models    # use it
mxkey migrate .env.local myapp                       # move a whole .env file into Keychain
mxkey run-here -- pnpm dev                           # run the project with all its secrets
mxkey backup add github                              # store 2FA recovery codes (single-use)
mxkey set --require-auth db.prod-postgres DATABASE_URL    # Touch ID on every read
```

`mxkey --help` is the canonical command reference. Full docs at [docs.mxkey.space](https://docs.mxkey.space/docs).

## Use as an agent skill

The repo ships with a Claude Code / Cursor / Codex skill (`SKILL.md` plus `references/`) that teaches AI agents to handle secrets safely — migrate `.env` files into Keychain, refuse secrets pasted into chat, suggest `--require-auth` for high-value keys, store 2FA recovery codes as single-use entries, and more.

**Via Homebrew** — `brew install bonnard-data/mxkey/mxkey` lays the skill down at `$(brew --prefix)/share/mxkey`. Symlink to enable:

```bash
ln -sfn "$(brew --prefix)/share/mxkey" ~/.claude/skills/mxkey       # Claude Code
ln -sfn "$(brew --prefix)/share/mxkey" ~/.cursor/skills/mxkey       # Cursor
```

**From source** — symlink the cloned repo into your editor's skills directory:

```bash
ln -sfn "$(pwd)" ~/.claude/skills/mxkey
```

**Via Sherpi** — install with the [`@sherpi/cli`](https://github.com/bonnard-data/sherpi-cli):

```bash
sherpi skills install mxkey
```

Or browse the public Sherpi catalog at [app.sherpi.dev/public/bonnard/mxkey](https://app.sherpi.dev/public/bonnard/mxkey).

## Documentation

| Topic | Where |
| ----- | ----- |
| Installation | [docs.mxkey.space/docs/install](https://docs.mxkey.space/docs/install) |
| Quickstart | [docs.mxkey.space/docs/quickstart](https://docs.mxkey.space/docs/quickstart) |
| CLI reference | [docs.mxkey.space/docs/cli-reference](https://docs.mxkey.space/docs/cli-reference) |
| Agent skill | [docs.mxkey.space/docs/skill](https://docs.mxkey.space/docs/skill) |
| Security model | [docs.mxkey.space/docs/security](https://docs.mxkey.space/docs/security) |
| Troubleshooting | [docs.mxkey.space/docs/troubleshooting](https://docs.mxkey.space/docs/troubleshooting) |

In-repo references (also bundled with the agent skill):

- [`SKILL.md`](./SKILL.md) — skill definition for Claude Code, Cursor, Codex
- [`references/setup.md`](./references/setup.md) — install / uninstall / PATH troubleshooting
- [`references/migrate-from-env.md`](./references/migrate-from-env.md) — `.env` migration walkthrough
- [`references/troubleshooting.md`](./references/troubleshooting.md) — common errors
- [`references/keychain-deep-dive.md`](./references/keychain-deep-dive.md) — how mxkey wraps the `security` CLI + the honest threat model

## Security model

Secrets are stored as macOS Keychain *generic password* entries — encrypted at rest, unlocked by your login password, scoped to your user UID. mxkey wraps the `security` CLI that ships with macOS; it doesn't invent its own crypto.

**What mxkey protects against:** plaintext leaks via `.env` files in git, shell history, `export` lines in shell rc files, screen-shares, log capture, and credential exfiltration from compromised dev tools that read `.env` paths.

**What mxkey doesn't protect against:** an attacker already running as your user. They can read your Keychain directly. There is also a millisecond-scale window where a secret appears in process argv during `mxkey run` and `mxkey set` — observable by a same-UID attacker running `ps aww` in a tight loop. See [`references/keychain-deep-dive.md`](./references/keychain-deep-dive.md) for the full breakdown.

For high-value secrets (production DBs, billing APIs), use `mxkey set --require-auth <name>` — every read triggers a macOS confirmation prompt (Touch ID on eligible Macs).

## Releases

All releases are signed with **SLSA build provenance** via [Sigstore](https://sigstore.dev). Verify any release artifact:

```bash
gh attestation verify mxkey-1.0.0.tar.gz --repo bonnard-data/mxkey
```

The latest release: [v1.0.0](https://github.com/bonnard-data/mxkey/releases/tag/v1.0.0). See [CHANGELOG.md](./CHANGELOG.md) for full history.

## Contributing

Issues and pull requests welcome at [github.com/bonnard-data/mxkey](https://github.com/bonnard-data/mxkey/issues). For larger changes, please open an issue first to discuss.

## About

mxkey is part of the [Sherpi](https://app.sherpi.dev) skill catalog, built and maintained by [Bonnard](https://bonnard.dev). Designed for developers and AI agents that need to handle secrets safely.

## License

[MIT](./LICENSE) © 2025–present Bonnard
