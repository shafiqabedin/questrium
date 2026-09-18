-- Questrium v0.1.0 — behaviours and the point ledger
--
-- Two rules shape this file:
--   * point_events is append-only. An undo writes undone_at; it never deletes
--     (blueprint §4.7). Teachers misclick while teaching, and a tool that
--     punishes a child because of a mis-tap is worse than no tool. The same
--     property gives us the audit trail a school will eventually ask for.
--   * Behaviours are teacher-authored (§4.4). We ship suggestions, not rules.

-- ---------------------------------------------------------------------------
-- behaviours
-- ---------------------------------------------------------------------------
-- The one-tap presets. Keeping an award under three seconds (§4.5) is what makes
-- this tool usable mid-lesson, and it depends on these existing.

create type stat_kind as enum ('hp', 'ap', 'xp', 'gp');

create table behaviors (
  id          uuid primary key default gen_random_uuid(),
  class_id    uuid not null references classes (id) on delete cascade,
  label       text not null,
  icon        text not null default '',
  stat        stat_kind not null,
  delta       integer not null,
  sort_order  integer not null default 0,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),

  constraint behaviors_label_not_blank check (length(trim(label)) > 0),
  constraint behaviors_delta_not_zero  check (delta <> 0),
  -- XP and GP only ever go up (blueprint §4.1). HP and AP may go either way.
  constraint behaviors_xp_gp_positive  check (stat not in ('xp', 'gp') or delta > 0)
);

create index behaviors_class_idx on behaviors (class_id, sort_order) where is_active;

comment on table behaviors is
  'Teacher-authored one-tap point presets. The three-second award path (§4.5) '
  'depends on these; ad-hoc amounts are the exception, not the norm.';

-- ---------------------------------------------------------------------------
-- point_events
-- ---------------------------------------------------------------------------

create table point_events (
  id          uuid primary key default gen_random_uuid(),
  class_id    uuid not null references classes (id) on delete cascade,
  student_id  uuid not null references students (id) on delete cascade,
  behavior_id uuid references behaviors (id) on delete set null,

  stat        stat_kind not null,
  delta       integer not null,
  -- What the stat actually became, after clamping and multipliers. Without this
  -- a later config change makes the history impossible to interpret.
  resulting_value integer not null,

  note        text not null default '',
  awarded_by  uuid not null references teachers (id),
  created_at  timestamptz not null default now(),

  -- Append-only: an undo sets these two, and the row stays.
  undone_at   timestamptz,
  undone_by   uuid references teachers (id),

  constraint point_events_undo_consistent
    check ((undone_at is null) = (undone_by is null))
);

create index point_events_class_recent_idx  on point_events (class_id, created_at desc);
create index point_events_student_idx       on point_events (student_id, created_at desc);
-- Powers the teacher's recent-activity list, which is the undo surface.
create index point_events_active_idx        on point_events (class_id, created_at desc)
  where undone_at is null;

comment on table point_events is
  'Append-only ledger of every point change. Undo writes undone_at rather than '
  'deleting (blueprint §4.7): teachers misclick mid-lesson, and the corrected '
  'history is also the audit trail.';

-- Enforce append-only in the database, not by convention. A DELETE here would
-- erase a child's record; make it impossible rather than merely discouraged.
create or replace function reject_point_event_mutation()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'point_events is append-only: cannot delete (use undo)';
  end if;

  -- An undo is the only permitted change, and only once.
  if old.undone_at is not null then
    raise exception 'this point event is already undone';
  end if;

  if new.id <> old.id
     or new.student_id <> old.student_id
     or new.stat <> old.stat
     or new.delta <> old.delta
     or new.created_at <> old.created_at then
    raise exception 'point_events is append-only: only undo fields may change';
  end if;

  return new;
end;
$$;

create trigger point_events_no_delete
  before delete on point_events
  for each row execute function reject_point_event_mutation();

create trigger point_events_append_only
  before update on point_events
  for each row execute function reject_point_event_mutation();
