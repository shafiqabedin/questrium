-- Questrium v0.1.0 — table privileges
--
-- RLS and GRANT are two separate gates and both must be open. A policy filters
-- which ROWS a role may see; a grant decides whether the role may touch the table
-- at all. Supabase's hosted setup grants these by default, which makes their
-- absence easy to miss — it works there and fails anywhere else. Being explicit
-- also documents the intended surface.
--
-- The privileges here are deliberately narrow. Row-level restriction is still
-- enforced by the policies in 0003; these grants only decide which VERBS a role
-- can attempt.

-- Students and teachers both arrive as `authenticated`; a student's session
-- carries a student_id claim instead of a sub. A grant alone does not separate
-- them — both roles may ATTEMPT these verbs, and it is the policies in 0003 and
-- the restrictive policies in 0006 that decide which rows qualify. A student's
-- UPDATE reaches the table and then matches zero rows; 0006 turns that silent
-- no-op into an explicit error.
grant select, insert, update, delete on
  classes, students, teams, team_members, behaviors
to authenticated;

grant select, insert, update on teachers to authenticated;

-- No DELETE on point_events, at any level: the table is append-only (blueprint
-- §4.7) and the trigger in 0002 enforces it. Withholding the privilege as well
-- means an accidental delete fails at the permission check, before the trigger.
grant select, insert, update on point_events to authenticated;

grant select on classmates_public, teammates, class_display to authenticated;

-- The join page needs to resolve a class code before anyone is logged in, so the
-- anonymous role gets exactly one function and no table access.
grant execute on function generate_join_code() to authenticated;
grant execute on function create_class(text) to authenticated;
grant execute on function add_student(uuid, text, text, character_class) to authenticated;
grant execute on function set_student_pin(uuid, text) to authenticated;
grant execute on function current_student_id() to authenticated, anon;
grant execute on function teacher_owns_class(uuid) to authenticated;
grant execute on function student_in_class(uuid) to authenticated;
grant execute on function default_class_config() to authenticated;

-- Future tables should not silently become readable; grants are per-table by
-- intent, so no ALTER DEFAULT PRIVILEGES here.
