# Development setup

## Node

This machine has no system Node, no sudo, and no `nodejs` lmod module, so Node
lives in a dedicated conda environment.

```bash
source ~/miniconda3/etc/profile.d/conda.sh
conda activate questrium
```

Node 24 LTS, npm 11. Created once with:

```bash
conda create -y -n questrium -c conda-forge 'nodejs=24.*'
```

LTS rather than latest, deliberately: this project will iterate for a school year
and stability matters more than new features.

**Every shell needs the activate line** before `npm` works. If you get
`npm: command not found`, that is the missing step.

## Environment variables

`.env.local` holds the Supabase URL and anon key. It is gitignored. Copy from
`.env.example` if you need to recreate it.

Both values are safe in a browser bundle — the anon key's access is bounded by Row
Level Security, not secrecy. The `service_role` key is different: it bypasses RLS
entirely and must never appear in frontend code or any `VITE_` variable.

## Commands

```bash
npm install       # once, and after a dependency change
npm run dev       # dev server on http://localhost:5173
npm run build     # production build to dist/
npm run check     # types + lint + tests — run before calling anything done
npm test          # unit tests
```

## Git

Two GitHub identities on this machine, routed by hostname:

```
github.com      ->  ~/.ssh/id_ed25519_github   (personal — this project)
github.ibm.com  ->  ~/.ssh/id_ed25519          (work)
```

Automatic; `git push` needs no flags. This repo also has a local
`user.name`/`user.email` so commits here do not carry a work identity.

## Supabase

Project `jpedtlimardqhdahanpu`. Google sign-in is the only enabled auth provider —
email signup is deliberately off, since nobody should be able to self-register on
a children's app.

**Free-tier projects pause after 7 days of inactivity**, which will happen over a
school break. One click in the dashboard to restore. Put it on the term-start
checklist rather than designing around it.

## Testing the schema

```bash
./supabase/tests/run.sh
```

Applies the migrations to a scratch local Postgres and runs the RLS suite. A
local Postgres from the conda env rather than a container: rootless podman cannot
map the UIDs Postgres needs on this machine's NFS-backed storage.

`supabase/tests/00_supabase_shim.sql` recreates the parts of Supabase the
migrations depend on — `auth.users`, `auth.uid()`, `auth.jwt()`, and the
anon/authenticated roles — so the real migrations run unmodified. Test-only;
never applied to a hosted project.

### One Postgres behaviour worth knowing

A student's `UPDATE` against their own row does not raise an error. It affects
**zero rows**. A restrictive policy's `USING` clause filters rows out rather than
erroring, and `WITH CHECK` is never evaluated because no row qualified.

The security is real — nothing is written, and the suite asserts the value is
unchanged afterwards — but the denial is silent. So tests here assert on the
*effect* (0 rows affected, value unchanged), not on an exception. If you write a
new RLS test and expect an error that never comes, this is why.
