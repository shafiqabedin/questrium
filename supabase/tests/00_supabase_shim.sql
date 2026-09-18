-- Local test shim: the parts of Supabase the migrations depend on.
--
-- Supabase provides auth.users, auth.uid(), auth.jwt(), and the anon/authenticated
-- roles. This recreates just enough of them to run the real migrations unmodified
-- against a plain Postgres, so the schema and its RLS policies can be tested
-- without a network round-trip to a hosted project.
--
-- Test-only. Never applied to a real Supabase project.

create schema if not exists auth;

create table if not exists auth.users (
  id    uuid primary key default gen_random_uuid(),
  email text
);

-- Supabase reads these from the request JWT; here they come from session GUCs
-- that the tests set to impersonate a teacher or a student.
create or replace function auth.uid()
returns uuid
language sql
stable
as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;

create or replace function auth.jwt()
returns jsonb
language sql
stable
as $$
  select coalesce(
    nullif(current_setting('request.jwt.claims', true), '')::jsonb,
    '{}'::jsonb
  );
$$;

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin bypassrls;
  end if;
end $$;

grant usage on schema public to anon, authenticated;
