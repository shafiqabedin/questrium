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

## This machine cannot reach Postgres directly

Egress filtering here allows HTTPS (443) but blocks Postgres (5432/6543). The TCP
connection opens and then the server never replies to the SSL request — it looks
like a hang, not a refusal, which makes it easy to misdiagnose as a bad password.

Consequences:

- **The app is unaffected.** It talks to Supabase over HTTPS, so `npm run dev`,
  auth, queries, and realtime all work normally.
- **`psql` against Supabase, the Supabase CLI's `db push`, and anything else
  needing a direct connection will not work from here.** Apply migrations through
  the dashboard's SQL Editor instead, in filename order.
- **Local schema testing is unaffected** — `./supabase/tests/run.sh` uses a
  Postgres running on this machine.

Never commit a connection string. They belong outside the repo entirely;
`.gitignore` carries patterns for the obvious filenames as a backstop, but the
string contains the database password and should not be in a file under the repo
at all.

## Verifying a migration run

After applying `0001`–`0006` to a project, this should match:

```sql
select
  (select count(*) from information_schema.tables
     where table_schema='public' and table_type='BASE TABLE') as tables,      -- 7
  (select count(*) from information_schema.views
     where table_schema='public') as views,                                    -- 3
  (select count(*) from pg_policies where schemaname='public') as policies,    -- 27
  (select count(*) from information_schema.columns
     where table_name='class_display'
       and column_name in ('hp','hp_max','is_fallen')) as projector_hp_leak,   -- 0
  (select count(*) from information_schema.columns
     where table_name='classmates_public'
       and column_name in ('hp','is_fallen','pin_hash','hp_loss_multiplier'))
     as classmate_leak;                                                        -- 0
```

The two zeros are the ones that matter: they confirm the projector and
class-wide views carry no health data, which is blueprint §4.2 enforced by the
schema rather than by the UI remembering to leave it out. If either becomes
non-zero, a view has been widened and that is a privacy regression, not a
cosmetic one.

Tables and views are stable numbers. Function counts vary by database — the test
database also holds the suite's own assertion helpers — so count objects by name
rather than trusting a total.

## Re-running a migration

The migrations are not idempotent: `create table` and `create type` both error if
the object exists, which stops the script at that point. That makes an accidental
re-run mostly harmless (it fails early and changes nothing) but it does mean you
cannot use a re-run to "top up" a partial apply. If a migration half-applied,
work out what landed before continuing.
