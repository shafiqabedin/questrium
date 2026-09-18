-- RLS and schema behaviour tests.
--
-- These matter more than most tests in this project: the policies encode who can
-- see a child's health record and who can change their points. A bug here is not
-- a crash, it is a quiet privacy leak.
--
-- Run: psql -f 00_supabase_shim.sql, migrations, then this file.

\set ON_ERROR_STOP on
\pset pager off

create or replace function assert(condition boolean, label text)
returns void language plpgsql as $$
begin
  if condition then
    raise notice 'PASS  %', label;
  else
    raise exception 'FAIL  %', label;
  end if;
end $$;

create or replace function assert_fails(stmt text, label text)
returns void language plpgsql as $$
begin
  begin
    execute stmt;
    raise exception 'FAIL  % (expected an error, none raised)', label;
  exception
    when others then
      if sqlerrm like 'FAIL%' then raise; end if;
      raise notice 'PASS  % (blocked: %)', label, left(sqlerrm, 60);
  end;
end $$;

-- Impersonation helpers, mirroring how Supabase presents a session.
create or replace function act_as_teacher(tid uuid, temail text default 't@example.com')
returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', tid::text, true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', tid, 'email', temail)::text, true);
  execute 'set local role authenticated';
end $$;

create or replace function act_as_student(sid uuid)
returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claims',
    json_build_object('student_id', sid)::text, true);
  execute 'set local role authenticated';
end $$;

-- ===========================================================================
do $$
declare
  t1 uuid := gen_random_uuid();   -- teacher A
  t2 uuid := gen_random_uuid();   -- teacher B
  c1 uuid; c2 uuid;
  team_a uuid; team_b uuid;
  s_ann uuid; s_ben uuid; s_cal uuid;
  ev uuid;
  n integer;
  v integer;
begin
  raise notice '--- setup ---';
  insert into auth.users (id, email) values (t1, 'a@example.com'), (t2, 'b@example.com');

  perform act_as_teacher(t1, 'a@example.com');
  c1 := (select id from create_class('Room 12'));
  perform assert(c1 is not null, 'teacher can create a class');

  perform assert(
    (select join_code from classes where id = c1) ~ '^[A-Z]{4}-[0-9]{4}$',
    'join code matches the expected format');

  perform assert(
    (select count(*) from behaviors where class_id = c1) = 10,
    'starter behaviours are seeded');

  perform assert(
    (select config -> 'hp_loss_enabled' from classes where id = c1)::text = 'true',
    'hp_loss_enabled defaults on (switchable per class)');

  perform assert(
    (select config -> 'team_consequences' from classes where id = c1)::text = 'false',
    'team_consequences defaults OFF (ADR 0002)');

  s_ann := (select id from add_student(c1, 'Ann', 'B', 'mender'));
  s_ben := (select id from add_student(c1, 'Ben', 'C', 'guardian'));
  s_cal := (select id from add_student(c1, 'Cal', 'D', 'sage'));

  perform assert(
    (select hp from students where id = s_ben) = 100,
    'guardian starts at 100 hp, from class config');
  perform assert(
    (select ap from students where id = s_cal) = 40,
    'sage starts at 40 ap, from class config');

  insert into teams (class_id, name) values (c1, 'Foxes') returning id into team_a;
  insert into teams (class_id, name) values (c1, 'Owls')  returning id into team_b;
  insert into team_members (team_id, student_id) values (team_a, s_ann), (team_a, s_ben);
  insert into team_members (team_id, student_id) values (team_b, s_cal);

  -- Teacher B, a different classroom entirely.
  perform act_as_teacher(t2, 'b@example.com');
  c2 := (select id from create_class('Room 3'));

  raise notice '--- teacher isolation ---';
  perform assert((select count(*) from classes) = 1,
    'teacher B sees only their own class');
  perform assert((select count(*) from students) = 0,
    'teacher B sees no students from teacher A''s class');
  perform assert_fails(
    format('select add_student(%L, %L)', c1, 'Intruder'),
    'teacher B cannot add a student to teacher A''s class');
  -- RLS makes the row invisible, so this UPDATE matches nothing and succeeds
  -- with zero rows affected. The isolation is real; assert on the effect.
  execute format('update students set xp = 9999 where id = %L', s_ann);
  get diagnostics n = row_count;
  perform assert(n = 0, 'teacher B''s write to teacher A''s student affects 0 rows');

  raise notice '--- teacher can award and undo ---';
  perform act_as_teacher(t1, 'a@example.com');
  insert into point_events (class_id, student_id, stat, delta, resulting_value, awarded_by)
  values (c1, s_ann, 'xp', 25, 25, t1) returning id into ev;
  perform assert(ev is not null, 'teacher can award points');

  update point_events set undone_at = now(), undone_by = t1 where id = ev;
  perform assert(
    (select undone_at is not null from point_events where id = ev),
    'teacher can undo an award');

  perform assert_fails(
    format('update point_events set undone_at = now(), undone_by = %L where id = %L', t1, ev),
    'cannot undo the same event twice');

  perform assert_fails(
    format('delete from point_events where id = %L', ev),
    'point_events cannot be deleted (append-only)');

  insert into point_events (class_id, student_id, stat, delta, resulting_value, awarded_by)
  values (c1, s_ann, 'xp', 10, 35, t1) returning id into ev;
  perform assert_fails(
    format('update point_events set delta = 500 where id = %L', ev),
    'cannot rewrite delta on an existing event');

  raise notice '--- student read scope ---';
  perform act_as_student(s_ann);

  perform assert(current_student_id() = s_ann, 'student claim resolves');

  select count(*) into n from classmates_public;
  perform assert(n = 3, 'student sees all 3 classmates in the public view');

  select count(*) into n from teammates;
  perform assert(n = 2, 'student sees only their own team in teammates (Ann + Ben)');

  perform assert(
    not exists (select 1 from teammates where id = s_cal),
    'Cal, on another team, is NOT in Ann''s teammates view');

  raise notice '--- students cannot write ---';
  -- A student UPDATE cannot be made to raise. A restrictive policy's USING clause
  -- FILTERS rows rather than erroring, and WITH CHECK never runs because no row
  -- qualified. So the guarantee to test is the effect: zero rows touched and the
  -- value unchanged. That is the actual security property; an error would only
  -- have been a nicer diagnostic.
  select xp into v from students where id = s_ann;
  execute format('update students set xp = 9999 where id = %L', s_ann);
  get diagnostics n = row_count;
  perform assert(n = 0, 'student XP self-grant affects 0 rows');
  reset role;
  perform assert((select xp from students where id = s_ann) = v,
    'student XP is unchanged after the attempt');
  perform act_as_student(s_ann);

  select hp into v from students where id = s_ann;
  execute format('update students set hp = 100 where id = %L', s_ann);
  get diagnostics n = row_count;
  perform assert(n = 0, 'student self-heal affects 0 rows');
  reset role;
  perform assert((select hp from students where id = s_ann) = v,
    'student HP is unchanged after the attempt');
  perform act_as_student(s_ann);
  perform assert_fails(
    format('insert into point_events (class_id, student_id, stat, delta, resulting_value, awarded_by) '
           || 'values (%L, %L, ''xp'', 500, 500, %L)', c1, s_ann, t1),
    'student cannot insert a point event');
  execute format('delete from students where id = %L', s_ben);
  get diagnostics n = row_count;
  perform assert(n = 0, 'student delete of a classmate affects 0 rows');
  reset role;
  perform assert(exists (select 1 from students where id = s_ben),
    'the classmate still exists after the attempted delete');
  perform act_as_student(s_ann);

  raise notice '--- privacy: what a student cannot read ---';
  select count(*) into n from behaviors;
  perform assert(n = 0, 'student cannot read the behaviour list or its point values');

  select count(*) into n from point_events where student_id = s_ben;
  perform assert(n = 0, 'student cannot read a classmate''s point history');

  select count(*) into n from point_events where student_id = s_ann;
  perform assert(n = 2, 'student CAN read their own point history');

  raise notice '--- projector view carries no hp (blueprint 4.2) ---';
  perform assert(
    not exists (
      select 1 from information_schema.columns
      where table_name = 'class_display'
        and column_name in ('hp', 'hp_max', 'is_fallen')
    ),
    'class_display has no hp or fallen columns by construction');

  perform assert(
    not exists (
      select 1 from information_schema.columns
      where table_name = 'classmates_public'
        and column_name in ('hp', 'is_fallen', 'pin_hash', 'hp_loss_multiplier')
    ),
    'classmates_public excludes hp, fallen, pin_hash, and the accommodation multiplier');

  perform assert(
    not exists (
      select 1 from information_schema.columns
      where table_name = 'teammates'
        and column_name in ('pin_hash', 'hp_loss_multiplier', 'xp', 'gp')
    ),
    'teammates excludes pin_hash, multiplier, xp, and gp');

  raise notice '--- fallen state derives from hp ---';
  reset role;
  perform act_as_teacher(t1, 'a@example.com');
  update students set hp = 0 where id = s_ben;
  perform assert((select is_fallen from students where id = s_ben),
    'hp 0 sets is_fallen automatically');
  update students set hp = 50 where id = s_ben;
  perform assert(not (select is_fallen from students where id = s_ben),
    'healing above 0 clears is_fallen');

  raise notice '--- constraints ---';
  perform assert_fails(
    format('update students set hp = -5 where id = %L', s_ben),
    'hp cannot go negative');
  perform assert_fails(
    format('update students set hp = 500 where id = %L', s_ben),
    'hp cannot exceed hp_max');
  perform assert_fails(
    format('update students set xp = -1 where id = %L', s_ben),
    'xp cannot go negative');
  perform assert_fails(
    format('insert into behaviors (class_id, label, stat, delta) values (%L, ''Bad'', ''xp'', -10)', c1),
    'an XP behaviour cannot be negative (xp never decreases)');
  perform assert_fails(
    format('insert into behaviors (class_id, label, stat, delta) values (%L, ''Zero'', ''hp'', 0)', c1),
    'a behaviour delta cannot be zero');
  perform assert_fails(
    format('insert into students (class_id, first_name, last_initial) values (%L, ''X'', ''YZ'')', c1),
    'last_initial is limited to one character (PII cap)');

  raise notice '--- pin handling ---';
  perform set_student_pin(s_ann, '1234');
  perform assert(
    (select pin_hash from students where id = s_ann) not like '%1234%',
    'PIN is hashed, not stored in plaintext');
  perform assert(
    (select pin_hash = crypt('1234', pin_hash) from students where id = s_ann),
    'hashed PIN verifies against the original');
  perform assert_fails(
    format('select set_student_pin(%L, %L)', s_ann, '12'),
    'a 2-digit PIN is rejected');
  perform assert_fails(
    format('select set_student_pin(%L, %L)', s_ann, 'abcd'),
    'a non-numeric PIN is rejected');

  reset role;
  raise notice '';
  raise notice '=== all assertions passed ===';
end $$;
