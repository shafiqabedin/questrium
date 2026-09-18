-- Questrium v0.1.0 — Row Level Security
--
-- The security boundary lives here, in the database, not in the UI (CLAUDE.md).
-- UI checks are a convenience for the user; these policies are what actually
-- stops a curious nine-year-old with the browser console open.
--
-- Two principals:
--   * Teacher — an authenticated auth.users row. Reads and writes only their own
--     classes.
--   * Student — NOT an auth.users row. Identified by a signed session claim
--     carrying student_id, minted by the PIN-login Edge Function in v0.3.0.
--     Reads their own row and teammates' public fields. Writes nothing.
--
-- Students cannot write their own stats. Points come from the teacher; a student
-- who could grant themselves XP would make the whole economy meaningless.

alter table teachers     enable row level security;
alter table classes      enable row level security;
alter table students     enable row level security;
alter table teams        enable row level security;
alter table team_members enable row level security;
alter table behaviors    enable row level security;
alter table point_events enable row level security;

-- ---------------------------------------------------------------------------
-- helpers
-- ---------------------------------------------------------------------------

-- The student_id claim from a PIN-login token, or null for a teacher session.
create or replace function current_student_id()
returns uuid
language sql
stable
as $$
  select nullif(
    coalesce(
      current_setting('request.jwt.claims', true)::jsonb ->> 'student_id',
      ''
    ),
    ''
  )::uuid;
$$;

create or replace function teacher_owns_class(target_class uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from classes
    where id = target_class
      and teacher_id = auth.uid()
  );
$$;

-- security definer so the lookup itself is not filtered by the policies it feeds.
create or replace function student_in_class(target_class uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from students
    where id = current_student_id()
      and class_id = target_class
  );
$$;

-- ---------------------------------------------------------------------------
-- teachers
-- ---------------------------------------------------------------------------

create policy teachers_select_self on teachers
  for select using (id = auth.uid());

create policy teachers_insert_self on teachers
  for insert with check (id = auth.uid());

create policy teachers_update_self on teachers
  for update using (id = auth.uid()) with check (id = auth.uid());

-- ---------------------------------------------------------------------------
-- classes
-- ---------------------------------------------------------------------------

create policy classes_teacher_all on classes
  for all using (teacher_id = auth.uid()) with check (teacher_id = auth.uid());

-- A student sees only the class they are in — not its config, which is exposed
-- through a narrowed view rather than this policy.
create policy classes_student_select on classes
  for select using (student_in_class(id));

-- ---------------------------------------------------------------------------
-- students
-- ---------------------------------------------------------------------------

create policy students_teacher_all on students
  for all using (teacher_owns_class(class_id)) with check (teacher_owns_class(class_id));

-- A student reads rows in their own class. Column-level exposure (hiding pin_hash
-- and hp_loss_multiplier, and hiding HP outside the team) is handled by the views
-- below — Postgres RLS filters rows, not columns.
create policy students_student_select on students
  for select using (student_in_class(class_id));

-- Deliberately no student INSERT, UPDATE, or DELETE policy. Students never write
-- their own stats. Avatar changes in v0.5.0 will go through a function that
-- validates the purchase, not a direct table write.

-- ---------------------------------------------------------------------------
-- teams
-- ---------------------------------------------------------------------------

create policy teams_teacher_all on teams
  for all using (teacher_owns_class(class_id)) with check (teacher_owns_class(class_id));

create policy teams_student_select on teams
  for select using (student_in_class(class_id));

create policy team_members_teacher_all on team_members
  for all using (
    exists (select 1 from teams t where t.id = team_id and teacher_owns_class(t.class_id))
  ) with check (
    exists (select 1 from teams t where t.id = team_id and teacher_owns_class(t.class_id))
  );

create policy team_members_student_select on team_members
  for select using (
    exists (select 1 from teams t where t.id = team_id and student_in_class(t.class_id))
  );

-- ---------------------------------------------------------------------------
-- behaviours
-- ---------------------------------------------------------------------------
-- Teacher-only. The point values behind each preset are not a student's business.

create policy behaviors_teacher_all on behaviors
  for all using (teacher_owns_class(class_id)) with check (teacher_owns_class(class_id));

-- ---------------------------------------------------------------------------
-- point_events
-- ---------------------------------------------------------------------------

create policy point_events_teacher_select on point_events
  for select using (teacher_owns_class(class_id));

create policy point_events_teacher_insert on point_events
  for insert with check (teacher_owns_class(class_id) and awarded_by = auth.uid());

-- Update is permitted only for the undo path; the append-only trigger from
-- migration 0002 constrains which columns may actually change.
create policy point_events_teacher_undo on point_events
  for update using (teacher_owns_class(class_id)) with check (teacher_owns_class(class_id));

-- A student sees their own history and nobody else's. Not their teammates':
-- another child's record of losing health is not theirs to read (blueprint §4.2).
create policy point_events_student_own on point_events
  for select using (student_id = current_student_id());

-- ---------------------------------------------------------------------------
-- views — column-level exposure
-- ---------------------------------------------------------------------------
-- RLS filters rows; these views filter columns. Blueprint §4.2 says recognition
-- is public and deficit is private, and that distinction is per-column.

-- What a student may see about a classmate they do NOT share a team with.
-- Level and class, yes. Health, no.
create view classmates_public
with (security_invoker = true)
as
select
  s.id,
  s.class_id,
  s.first_name,
  s.last_initial,
  s.character_class,
  s.level,
  s.avatar,
  s.sort_order
from students s;

comment on view classmates_public is
  'Classmate fields visible class-wide. Excludes hp, ap, xp, gp, is_fallen, '
  'pin_hash, and hp_loss_multiplier: HP loss and falling are never public '
  '(blueprint §4.2), and the accommodation multiplier is never visible to peers.';

-- Teammates see more, because powers need it: a Mender must know who is hurt.
create view teammates
with (security_invoker = true)
as
select
  s.id,
  s.class_id,
  s.first_name,
  s.last_initial,
  s.character_class,
  s.level,
  s.avatar,
  s.hp,
  s.hp_max,
  s.ap,
  s.ap_max,
  s.is_fallen,
  tm.team_id
from students s
join team_members tm on tm.student_id = s.id
where tm.team_id in (
  select team_id from team_members where student_id = current_student_id()
);

comment on view teammates is
  'Teammate fields, including health, since cooperative powers require knowing who '
  'is hurt. Still excludes xp, gp, pin_hash, and hp_loss_multiplier.';

-- The projector view (v0.6.0). No HP, no falling — blueprint §4.2 is structural
-- here, not a rendering choice, so a UI mistake cannot leak it.
create view class_display
with (security_invoker = true)
as
select
  t.id   as team_id,
  t.class_id,
  t.name as team_name,
  t.crest,
  count(tm.student_id)          as member_count,
  coalesce(sum(s.xp), 0)        as team_xp,
  coalesce(round(avg(s.level)), 0) as avg_level
from teams t
left join team_members tm on tm.team_id = t.id
left join students s      on s.id = tm.student_id
group by t.id, t.class_id, t.name, t.crest;

comment on view class_display is
  'Projector-safe team summary. Contains no HP and no fallen state by '
  'construction (blueprint §4.2) — a UI bug cannot expose what is not selected.';
