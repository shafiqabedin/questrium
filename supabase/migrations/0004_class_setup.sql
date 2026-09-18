-- Questrium v0.1.0 — class creation
--
-- One transactional function that creates a class with a unique join code and a
-- starter set of behaviours. Called from the app when a teacher makes a class.
--
-- The behaviours here are SUGGESTIONS, not defaults we are attached to. Blueprint
-- §4.4 makes the teacher the game master; she is expected to rewrite this list.
-- Two things are deliberate: every XP entry rewards effort or helping rather than
-- correctness (so the game never becomes a grade multiplier, blueprint §5), and
-- the HP deductions are small, because a 5-point loss reads as a nudge and a
-- 25-point loss reads as a punishment to a nine-year-old.

create or replace function create_class(class_name text)
returns classes
language plpgsql
security definer
set search_path = public
as $$
declare
  new_class classes;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  if length(trim(coalesce(class_name, ''))) = 0 then
    raise exception 'class name is required';
  end if;

  -- First class creates the teacher row; Google gives us the email.
  insert into teachers (id, email, display_name)
  values (
    auth.uid(),
    coalesce(auth.jwt() ->> 'email', ''),
    coalesce(auth.jwt() -> 'user_metadata' ->> 'full_name', '')
  )
  on conflict (id) do nothing;

  insert into classes (teacher_id, name, join_code, config)
  values (auth.uid(), trim(class_name), generate_join_code(), default_class_config())
  returning * into new_class;

  insert into behaviors (class_id, label, icon, stat, delta, sort_order) values
    -- Positive. Effort and helping — never correctness.
    (new_class.id, 'Helped a classmate',      'hands-helping', 'xp',  25, 10),
    (new_class.id, 'Great effort',            'sparkles',      'xp',  20, 20),
    (new_class.id, 'Joined in',               'hand',          'xp',  15, 30),
    (new_class.id, 'Work turned in',          'check',         'xp',  15, 40),
    (new_class.id, 'Cleaned up',              'broom',         'xp',  10, 50),
    (new_class.id, 'Kind to someone',         'heart',         'xp',  25, 60),
    -- Deductions. Small on purpose.
    (new_class.id, 'Off task',                'cloud',         'hp',  -5, 110),
    (new_class.id, 'Talking over others',     'speech',        'hp',  -5, 120),
    (new_class.id, 'Out of seat',             'walk',          'hp',  -5, 130),
    (new_class.id, 'Unkind words',            'storm',         'hp', -10, 140);

  return new_class;
end;
$$;

comment on function create_class is
  'Creates a class with a unique join code and starter behaviours, and the '
  'teacher row on first use. The behaviours are suggestions for the teacher to '
  'rewrite (blueprint §4.4).';

-- Adding a student sets their stats from the class config for their chosen class,
-- so the teacher's tuning applies from the first student onward.
create or replace function add_student(
  target_class uuid,
  p_first_name text,
  p_last_initial text default '',
  p_character_class character_class default null
)
returns students
language plpgsql
security definer
set search_path = public
as $$
declare
  cfg         jsonb;
  stats       jsonb;
  new_student students;
  next_order  integer;
begin
  if not teacher_owns_class(target_class) then
    raise exception 'not your class';
  end if;

  if length(trim(coalesce(p_first_name, ''))) = 0 then
    raise exception 'first name is required';
  end if;

  select config into cfg from classes where id = target_class;

  -- Stats arrive when a class is chosen. Until then, placeholders.
  if p_character_class is not null then
    stats := cfg -> 'starting_stats' -> p_character_class::text;
  else
    stats := jsonb_build_object('hp', 100, 'ap', 20);
  end if;

  select coalesce(max(sort_order), 0) + 10 into next_order
  from students where class_id = target_class;

  insert into students (
    class_id, first_name, last_initial, character_class,
    hp, hp_max, ap, ap_max, sort_order
  )
  values (
    target_class,
    trim(p_first_name),
    upper(trim(coalesce(p_last_initial, ''))),
    p_character_class,
    (stats ->> 'hp')::int, (stats ->> 'hp')::int,
    (stats ->> 'ap')::int, (stats ->> 'ap')::int,
    next_order
  )
  returning * into new_student;

  return new_student;
end;
$$;

-- Four digits, bcrypt-hashed. Weak in isolation, which is fine: the class code is
-- required too, attempts are rate-limited, and the alternative for nine-year-olds
-- is a password they cannot remember. Nothing sensitive sits behind it.
create or replace function set_student_pin(target_student uuid, new_pin text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  target_class uuid;
begin
  select class_id into target_class from students where id = target_student;

  if target_class is null then
    raise exception 'student not found';
  end if;

  if not teacher_owns_class(target_class) then
    raise exception 'not your class';
  end if;

  if new_pin !~ '^[0-9]{4}$' then
    raise exception 'PIN must be exactly 4 digits';
  end if;

  update students
  set pin_hash = crypt(new_pin, gen_salt('bf', 10))
  where id = target_student;
end;
$$;

comment on function set_student_pin is
  'Sets a student PIN, bcrypt-hashed. Teacher-only, because a nine-year-old will '
  'forget it and needs a one-click reset.';
