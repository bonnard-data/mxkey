#!/usr/bin/env bash
# mxkey skill — one-time setup
#
# Symlinks the bundled `mxkey` script into ~/.local/bin/ so it's on PATH.
# Idempotent: safe to re-run. Does nothing if `mxkey` is already available.

set -euo pipefail

if [[ "$(uname)" != "Darwin" ]]; then
  echo "mxkey requires macOS. Current OS: $(uname)" >&2
  exit 1
fi

# Resolve the bundled mxkey binary (alongside this script in the repo root).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLED="$SCRIPT_DIR/mxkey"

if [[ ! -f "$BUNDLED" ]]; then
  echo "error: expected bundled mxkey at $BUNDLED — is the skill installed?" >&2
  exit 1
fi

# Make it executable (in case the tarball didn't preserve perms).
chmod +x "$BUNDLED"

# Already on PATH?
if command -v mxkey >/dev/null 2>&1; then
  existing="$(command -v mxkey)"
  if [[ "$(readlink "$existing" 2>/dev/null || echo "$existing")" == "$BUNDLED" ]]; then
    echo "mxkey already set up at $existing" >&2
  else
    echo "mxkey is already on PATH at: $existing" >&2
    echo "(bundled copy at $BUNDLED not linked — not overwriting)" >&2
  fi
  exit 0
fi

# Ensure ~/.local/bin exists.
LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"

# Symlink.
ln -sf "$BUNDLED" "$LOCAL_BIN/mxkey"
echo "linked $LOCAL_BIN/mxkey -> $BUNDLED" >&2

# Verify PATH includes ~/.local/bin.
case ":$PATH:" in
  *":$LOCAL_BIN:"*)
    echo "$LOCAL_BIN is on PATH — you're good." >&2
    ;;
  *)
    echo "" >&2
    echo "WARNING: $LOCAL_BIN is not on PATH." >&2
    echo "Add this to your shell rc (~/.zshrc or ~/.bashrc):" >&2
    echo "" >&2
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\"" >&2
    echo "" >&2
    echo "Then reload: source ~/.zshrc" >&2
    ;;
esac

# Sanity check.
if "$BUNDLED" list >/dev/null 2>&1; then
  echo "mxkey ready." >&2
fi
