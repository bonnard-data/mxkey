# Changelog

All notable changes to mxkey are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/) and this
project adheres to [Semantic Versioning](https://semver.org/).

## [1.0.0]

First stable release. Public API of the CLI is now considered stable —
breaking changes from here will mean a 2.0.

### Added

- **`mxkey migrate <path-to-.env> [project-slug]`** — first-class CLI
  subcommand for moving a `.env` file into Keychain. Replaces the old
  `migrate-env.sh` helper script.
- **`--delete`** flag (and interactive prompt in TTY mode) — remove the
  original `.env` after a successful migration in one step. **`--keep`**
  skips both the prompt and the trim list.
- **`--no-init`** flag — by default, `mxkey migrate` now auto-writes
  `.env.mxkey` after a successful migration so `mxkey run-here` works
  out of the box. `--no-init` skips this. Existing manifests are never
  overwritten.
- **In-file duplicate detection** — collapses duplicate keys (last value
  wins, matching standard `.env` semantics) and reports the count.
- **Keychain overwrite warning** — flags entries that already exist with
  `[overwrites existing]` so users know before they confirm.
- **`mxkey --version` / `-v`** — version flag.
- **Pixel-key brand mark** at `assets/key.png`.
- **SLSA build provenance** for release artifacts via the new
  `.github/workflows/release.yml` workflow. Tag-push fires the workflow,
  which builds a tarball, attests it via Sigstore, and creates a GitHub
  release with both the tarball and a SHA256 checksum.

### Changed

- Migration summaries now show **character count only** (`(33 chars)`),
  never any portion of the value. No content lands in shell scrollback.
- Post-migrate output names the project group explicitly:
  `project.<slug> now contains N secret(s). wrote .env.mxkey. deleted <path>.`
  Followed by a single suggested next command (`mxkey run-here` when a
  manifest exists, `mxkey run <prefix>` otherwise).
- **Refactor**: extracted `_write_manifest` helper. `mxkey init` and
  `mxkey migrate` now share the manifest-writing path.

### Removed

- **`migrate-env.sh`** standalone script — superseded by
  `mxkey migrate`. Use the subcommand instead.

### Distribution

- **Homebrew tap published** at `bonnard-data/homebrew-mxkey`. Install:

  ```bash
  brew install bonnard-data/mxkey/mxkey
  ```

- **Marketing site** at https://mxkey.space.
- **Documentation** at https://docs.mxkey.space.

### Internal

- Repository restructured into a single canonical location at
  `~/GitHub/mxkey/` (the skill dir is now a symlink to it).
- Skill files (`SKILL.md`, `references/`) moved to the repo root.
- Public LICENSE (MIT, Bonnard) added.
- README rewritten for end users.

## [0.7.0] — superseded by 1.0.0

All 0.7.0 changes are included in 1.0.0. The 0.7.0 release exists for
historical reference at
<https://github.com/bonnard-data/mxkey/releases/tag/v0.7.0>.

## [0.6.0]

Initial public release.
