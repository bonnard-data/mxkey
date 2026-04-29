# Migrating a `.env` file to mxkey

## When to suggest this

The agent should offer migration whenever it encounters a `.env`, `.env.local`,
`.env.development`, `.env.production`, etc. in a project — especially if it's
tracked by git, has multiple API keys, or the user is about to add a new one.

**Always ask first.** Some `.env` files are intentionally project-local (loaded
by tooling that can't read env vars from the parent process — e.g. Next.js's
`.env.development` at build time). A migration might break them.

## The flow

```bash
bash migrate-env.sh <path-to-.env> [project-slug]
```

The script:

1. Parses the `.env` (skips comments and blanks, strips `export ` prefix and
   surrounding quotes).
2. Shows the list of keys with a 4-char preview (so the user can sanity-check
   the file was parsed correctly, without leaking full values).
3. Prompts `[y/N]` to confirm migration.
4. For each key, pipes the value into `mxkey set project.<slug>.<key_lower> <KEY>`
   via non-TTY stdin. **Values never touch shell history or intermediate files.**
5. Prints a summary and next steps.

## Naming result

A `.env.local` like:

```
STRIPE_SECRET_KEY=sk_live_...
DATABASE_URL=postgres://...
OPENAI_API_KEY=sk-...
```

…migrated with slug `myapp` becomes:

| mxkey name                         | env var              |
| ---------------------------------- | -------------------- |
| `project.myapp.stripe_secret_key`  | `STRIPE_SECRET_KEY`  |
| `project.myapp.database_url`       | `DATABASE_URL`       |
| `project.myapp.openai_api_key`     | `OPENAI_API_KEY`     |

## Rewriting the dev command

After migration, wrap the dev script with `mxkey run`:

```bash
# Before
pnpm dev

# After (all three keys injected)
mxkey run project.myapp.stripe_secret_key project.myapp.database_url project.myapp.openai_api_key -- pnpm dev
```

For apps with many keys, the command gets long. Two alternatives:

### Option 1: wrap in a tiny script

```bash
# scripts/dev.sh
#!/usr/bin/env bash
exec mxkey run \
  project.myapp.stripe_secret_key \
  project.myapp.database_url \
  project.myapp.openai_api_key \
  -- pnpm dev
```

### Option 2: regenerate `.env` on demand (for tools that insist on a file)

```bash
# scripts/gen-env.sh
#!/usr/bin/env bash
for name in stripe_secret_key database_url openai_api_key; do
  mxkey export "project.myapp.$name"
done > .env.local
```

Then `.env.local` is gitignored and regenerated per dev session. Not as tidy as
`mxkey run`, but necessary for some build tools.

## Adding to `.gitignore`

If the file isn't already covered, append:

```bash
echo '.env*' >> .gitignore
echo '!.env.example' >> .gitignore   # keep the template, if any
```

## After migration

1. Verify with `mxkey list` — the new secrets should appear.
2. Test the dev command with `mxkey run ...`.
3. **Trim the migrated keys out of the original `.env`.** The migration script
   prints the list of keys it moved at the end — remove exactly those lines
   from the file. If nothing non-secret remains, delete the file:
   `rm .env.local`. Leaving both copies means the secrets still live in
   plaintext and the two stores can drift when one is updated.
4. If the `.env` was ever committed, the secrets are already leaked — rotate
   each key at the provider before trusting the new setup.

## Edge cases

- **Multiline values** (RSA keys, JSON credentials). The simple parser won't
  handle `KEY="-----BEGIN..."` spanning lines. Migrate manually:
  `cat key.pem | mxkey set api.my-key MY_PEM`
- **Interpolation** (`API_URL=https://${DOMAIN}/api`). The parser stores the
  literal value — interpolation won't happen. If your code expects expanded
  values, do the expansion yourself before migrating.
- **Duplicate keys** in the same `.env`. The last one wins (standard `.env`
  semantics). Nothing special needed.
