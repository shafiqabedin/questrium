-- Questrium v0.1.0 — foundation schema
--
-- Teachers, classes, students, teams. The roster layer: everything needed before
-- any game mechanic exists. See docs/BLUEPRINT.md §6.3.
--
-- Design notes that matter here:
--   * Student PII is capped at a first name and a last initial (blueprint §7).
--     Do not add columns that widen this without an ADR.
--   * Game tuning lives in classes.config, not in code (§4.4), so the teacher can
--     retune without a deploy — including whether HP loss exists at all.
--   * Students have no auth.users row. They are identified by a class code plus a
--     PIN (§6.4), so there is no student credential to leak or reset by email.

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- teachers
-- ---------------------------------------------------------------------------
-- One row per authenticated teacher, keyed to Supabase auth. Google sign-in only.

create table teachers (
  id          uuid primary key references auth.users (id) on delete cascade,
  email       text not null,
  display_name text not null default '',
  created_at  timestamptz not null default now()
);

comment on table teachers is
  'Authenticated teachers. id matches auth.users. Google OAuth is the only sign-in path.';

-- ---------------------------------------------------------------------------
-- classes
-- ---------------------------------------------------------------------------
-- A classroom. The join_code is what students type to reach it.

create table classes (
  id         uuid primary key default gen_random_uuid(),
  teacher_id uuid not null references teachers (id) on delete cascade,
  name       text not null,
  join_code  text not null unique,
  config     jsonb not null default '{}'::jsonb,
  is_active  boolean not null default true,
  created_at timestamptz not null default now(),

  constraint classes_name_not_blank check (length(trim(name)) > 0),
  -- Ambiguous characters (0/O, 1/I/L) are excluded from the generator, because
  -- nine-year-olds type these off a projector.
  constraint classes_join_code_format check (join_code ~ '^[A-Z]{4}-[0-9]{4}$')
);

create index classes_teacher_idx on classes (teacher_id);

comment on column classes.config is
  'Teacher-tunable game settings. Defaults in default_class_config(). Includes '
  'hp_loss_enabled, so a class can run a purely positive economy with no schema change.';

-- The tuning surface. Every pedagogically meaningful number is here rather than
-- in code, so the teacher can change it without a deploy (blueprint §4.4).
create or replace function default_class_config()
returns jsonb
language sql
immutable
as $$
  select jsonb_build_object(
    -- The big fork from blueprint §10 Q7. Off means a purely positive economy:
    -- no HP loss, no falling, no consequences. Flip per class, no migration.
    'hp_loss_enabled',    true,
    -- Blueprint §4.3 / ADR 0002: never penalise a child for a classmate's
    -- behaviour. Ships off. Turning it on is the teacher's call, not a default.
    'team_consequences',  false,
    'starting_stats', jsonb_build_object(
      'guardian', jsonb_build_object('hp', 100, 'ap', 20, 'ap_regen', 5),
      'sage',     jsonb_build_object('hp',  60, 'ap', 40, 'ap_regen', 15),
      'mender',   jsonb_build_object('hp',  80, 'ap', 30, 'ap_regen', 10)
    ),
    -- XP needed to reach each level, cumulative. Index 0 is level 1.
    'level_thresholds',   jsonb_build_array(0, 100, 250, 450, 700, 1000, 1350, 1750, 2200, 2700),
    'gp_per_xp',          0.5,
    'overnight_hp_regen', 10,
    'weekend_full_heal',  true
  );
$$;

-- ---------------------------------------------------------------------------
-- students
-- ---------------------------------------------------------------------------
-- No auth.users row, no email, no password. A first name, a last initial, a PIN.

create type character_class as enum ('guardian', 'sage', 'mender');

create table students (
  id            uuid primary key default gen_random_uuid(),
  class_id      uuid not null references classes (id) on delete cascade,

  -- The entire extent of student PII. See blueprint §7 before adding anything.
  first_name    text not null,
  last_initial  text not null default '',

  -- bcrypt via pgcrypto. Never store or log a PIN in plaintext.
  pin_hash      text,

  character_class character_class,
  level         integer not null default 1,
  hp            integer not null default 100,
  hp_max        integer not null default 100,
  ap            integer not null default 20,
  ap_max        integer not null default 20,
  xp            integer not null default 0,
  gp            integer not null default 0,

  -- Quiet accommodation for students whose behaviour plan needs it (blueprint §5).
  -- Invisible to other students by design: an accommodation must not become a label.
  hp_loss_multiplier numeric(3,2) not null default 1.0,

  avatar        jsonb not null default '{}'::jsonb,
  is_fallen     boolean not null default false,
  sort_order    integer not null default 0,
  created_at    timestamptz not null default now(),

  constraint students_first_name_not_blank check (length(trim(first_name)) > 0),
  constraint students_last_initial_short   check (length(last_initial) <= 1),
  constraint students_level_positive       check (level >= 1),
  constraint students_hp_in_range          check (hp >= 0 and hp <= hp_max),
  constraint students_ap_in_range          check (ap >= 0 and ap <= ap_max),
  -- XP never decreases (blueprint §4.1); this only guards against negatives.
  constraint students_xp_non_negative      check (xp >= 0),
  constraint students_gp_non_negative      check (gp >= 0),
  constraint students_multiplier_sane      check (hp_loss_multiplier >= 0 and hp_loss_multiplier <= 2)
);

create index students_class_idx on students (class_id, sort_order);

comment on table students is
  'Class roster. Deliberately no auth.users row, no email, no password — students '
  'authenticate with a class code plus PIN (blueprint §6.4). PII is capped at a '
  'first name and last initial (§7).';

comment on column students.hp_loss_multiplier is
  'Per-student HP-loss scaling for IEP/behaviour-plan accommodations. 0 exempts a '
  'student entirely. Never surfaced to other students.';

-- is_fallen is derived from hp, so keep it consistent in one place rather than
-- trusting every caller to remember.
create or replace function sync_student_fallen()
returns trigger
language plpgsql
as $$
begin
  new.is_fallen := (new.hp <= 0);
  return new;
end;
$$;

create trigger students_sync_fallen
  before insert or update of hp on students
  for each row execute function sync_student_fallen();

-- ---------------------------------------------------------------------------
-- teams
-- ---------------------------------------------------------------------------
-- Teams of 4–6 with a mix of classes, so no student can function alone (§3.4).

create table teams (
  id         uuid primary key default gen_random_uuid(),
  class_id   uuid not null references classes (id) on delete cascade,
  name       text not null,
  crest      text not null default '',
  created_at timestamptz not null default now(),

  constraint teams_name_not_blank check (length(trim(name)) > 0),
  unique (class_id, name)
);

create index teams_class_idx on teams (class_id);

create table team_members (
  team_id    uuid not null references teams (id) on delete cascade,
  student_id uuid not null references students (id) on delete cascade,
  joined_at  timestamptz not null default now(),

  primary key (team_id, student_id),
  -- A student belongs to at most one team at a time.
  unique (student_id)
);

-- ---------------------------------------------------------------------------
-- join codes
-- ---------------------------------------------------------------------------

-- Excludes 0/O/1/I/L — students read these off a projector and mistype them.
create or replace function generate_join_code()
returns text
language plpgsql
as $$
declare
  letters text := 'ABCDEFGHJKMNPQRSTUVWXYZ';
  code    text;
  tries   integer := 0;
begin
  loop
    code := (
      select string_agg(substr(letters, 1 + floor(random() * length(letters))::int, 1), '')
      from generate_series(1, 4)
    ) || '-' || lpad(floor(random() * 10000)::text, 4, '0');

    exit when not exists (select 1 from classes where join_code = code);

    tries := tries + 1;
    if tries > 50 then
      raise exception 'could not generate a unique join code after % attempts', tries;
    end if;
  end loop;

  return code;
end;
$$;
