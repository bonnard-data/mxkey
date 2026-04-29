#!/usr/bin/env bash
# mxkey skill — .env migration helper
#
# Reads a .env file, asks the user to confirm each key, and pipes values
# into `mxkey set <name> <ENV_VAR>` one at a time.
#
# Usage: bash migrate-env.sh <path-to-.env> [project-slug]
# Example: bash migrate-env.sh .env.local myapp
#   -> creates project.myapp.stripe_secret_key, project.myapp.db_url, etc.
#
# Values never land on disk or in shell history — they go straight from the
# .env file into a non-TTY stdin read by `mxkey set`.

set -euo pipefail

if [[ "$(uname)" != "Darwin" ]]; then
  echo "mxkey requires macOS." >&2
  exit 1
fi

if ! command -v mxkey >/dev/null 2>&1; then
  echo "error: mxkey not on PATH. Run setup.sh first." >&2
  exit 1
fi

ENV_FILE="${1:-}"
PROJECT="${2:-$(basename "$PWD")}"

if [[ -z "$ENV_FILE" ]]; then
  echo "usage: bash migrate-env.sh <path-to-.env> [project-slug]" >&2
  exit 2
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "error: $ENV_FILE does not exist" >&2
  exit 1
fi

echo "Project slug: $PROJECT"
echo "Reading: $ENV_FILE"
echo ""

# Parse .env into name=value pairs. Rules:
#   - Skip blank lines and comments (#...)
#   - Strip optional `export ` prefix
#   - Strip surrounding single/double quotes from values
#   - Keep the raw value — don't expand $VARs
parse_env() {
  awk '
    /^[[:space:]]*($|#)/ { next }
    {
      line = $0
      sub(/^[[:space:]]*export[[:space:]]+/, "", line)
      eq = index(line, "=")
      if (eq == 0) next
      key = substr(line, 1, eq - 1)
      val = substr(line, eq + 1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
      # Strip matching surrounding quotes only
      if (val ~ /^".*"$/) val = substr(val, 2, length(val) - 2)
      else if (val ~ /^'"'"'.*'"'"'$/) val = substr(val, 2, length(val) - 2)
      if (key == "") next
      print key "\t" val
    }
  ' "$ENV_FILE"
}

# Build an array of key<TAB>value lines.
# (Bash 3.2 compatible — macOS ships /bin/bash 3.2, so no `mapfile`.)
PAIRS=()
while IFS= read -r line || [[ -n "$line" ]]; do
  PAIRS+=("$line")
done < <(parse_env)

if [[ ${#PAIRS[@]} -eq 0 ]]; then
  echo "No key=value pairs found in $ENV_FILE." >&2
  exit 0
fi

echo "Found ${#PAIRS[@]} key(s):"
for p in "${PAIRS[@]}"; do
  key="${p%%	*}"
  val="${p#*	}"
  # Show first 4 chars of value as a sanity preview, never more.
  preview="${val:0:4}"
  echo "  $key  (starts with: ${preview}…)"
done
echo ""

# Decide confirmation mode:
#   - Interactive (TTY stdin): per-key [Y/n/a/q] prompt, default yes.
#   - Non-interactive (piped/CI): single batch confirm, all-or-nothing.
INTERACTIVE=0
[[ -t 0 ]] && INTERACTIVE=1

if [[ $INTERACTIVE -eq 0 ]]; then
  read -r -p "Migrate all of these under project.$PROJECT.* ? [y/N] " ans
  [[ "$ans" == "y" || "$ans" == "Y" ]] || { echo "Aborted."; exit 0; }
else
  echo "Review each key [Y=migrate / n=skip / a=all remaining / q=quit]:"
  echo ""
fi

migrated=0
skipped=0
MIGRATED_KEYS=()
migrate_rest=0  # set to 1 when user picks 'a'
for p in "${PAIRS[@]}"; do
  key="${p%%	*}"
  val="${p#*	}"
  # Name in mxkey: project.<slug>.<lowercased key>
  lower_key="$(echo "$key" | tr '[:upper:]' '[:lower:]')"
  name="project.$PROJECT.$lower_key"

  if [[ -z "$val" ]]; then
    echo "  SKIP $key (empty value)" >&2
    skipped=$((skipped + 1))
    continue
  fi

  # Per-key prompt when interactive and the user hasn't picked "all".
  if [[ $INTERACTIVE -eq 1 && $migrate_rest -eq 0 ]]; then
    preview="${val:0:4}"
    printf '  %s → %s (starts with %s…) [Y/n/a/q]: ' "$key" "$name" "$preview"
    read -r ans
    case "$ans" in
      n|N)
        echo "  SKIP $key" >&2
        skipped=$((skipped + 1))
        continue
        ;;
      a|A)
        migrate_rest=1
        ;;
      q|Q)
        echo "  Quit — stopping here." >&2
        break
        ;;
      *)  # empty (default yes) or y/Y
        ;;
    esac
  fi

  # Pipe value into mxkey set via non-TTY stdin.
  printf '%s' "$val" | mxkey set "$name" "$key" >/dev/null
  echo "  SET  $name  ($key)"
  MIGRATED_KEYS+=("$key")
  migrated=$((migrated + 1))
done

echo ""
echo "Migrated $migrated / ${#PAIRS[@]} secrets. Skipped: $skipped."
echo ""
echo "Next steps:"
echo "  1. Verify with: mxkey list"
echo "  2. Wrap your dev command: mxkey run project.$PROJECT -- <cmd>"
echo "  3. Add .env* to .gitignore if not already:"
if [[ -f .gitignore ]] && grep -qE '^\.env' .gitignore; then
  echo "     (already covered in .gitignore)"
else
  echo "     echo '.env*' >> .gitignore"
fi

if (( migrated > 0 )); then
  echo ""
  echo "IMPORTANT — the original .env still contains plaintext secrets."
  echo "Remove these migrated keys from $ENV_FILE (keep any non-secret config):"
  for k in "${MIGRATED_KEYS[@]}"; do
    echo "  - $k"
  done
  echo ""
  echo "Or delete the file entirely once you've moved any non-secret settings elsewhere:"
  echo "  rm $ENV_FILE"
fi
