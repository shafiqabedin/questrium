-- Questrium v0.1.0 — make student writes fail loudly
--
-- Students already cannot write: no permissive UPDATE/INSERT/DELETE policy names
-- them, so no row ever qualifies and their statements affect 0 rows. That is
-- correct, but it is SILENT — a bug in our own code that tried to write as a
-- student would look like a no-op instead of an error, and a future permissive
-- policy added for some other reason could widen the hole without anything
-- failing.
--
-- These restrictive policies make the denial explicit and loud. RESTRICTIVE
-- policies AND with the permissive ones, so this cannot be bypassed by adding
-- another permissive policy later — which is exactly the failure mode worth
-- guarding against, since the thing being protected is a child's point record.

-- Teacher sessions carry a sub claim (auth.uid() is non-null); student sessions
-- carry student_id instead. So "this is a student session" is auth.uid() is null.
create policy students_no_student_write on students
  as restrictive
  for update
  using (auth.uid() is not null)
  with check (auth.uid() is not null);

create policy students_no_student_insert on students
  as restrictive
  for insert
  with check (auth.uid() is not null);

create policy students_no_student_delete on students
  as restrictive
  for delete
  using (auth.uid() is not null);

-- Same for the point ledger: only a teacher session may write to it.
create policy point_events_no_student_write on point_events
  as restrictive
  for insert
  with check (auth.uid() is not null);

create policy point_events_no_student_update on point_events
  as restrictive
  for update
  using (auth.uid() is not null)
  with check (auth.uid() is not null);

-- And for team structure, which is the teacher's to arrange. Note these name the
-- write verbs individually rather than using `for all`: `for all` would cover
-- SELECT too, and students must be able to read their own team membership for the
-- teammates view (and therefore for cooperative powers) to work.
create policy teams_no_student_insert on teams
  as restrictive for insert with check (auth.uid() is not null);
create policy teams_no_student_update on teams
  as restrictive for update using (auth.uid() is not null) with check (auth.uid() is not null);
create policy teams_no_student_delete on teams
  as restrictive for delete using (auth.uid() is not null);

create policy team_members_no_student_insert on team_members
  as restrictive for insert with check (auth.uid() is not null);
create policy team_members_no_student_update on team_members
  as restrictive for update using (auth.uid() is not null) with check (auth.uid() is not null);
create policy team_members_no_student_delete on team_members
  as restrictive for delete using (auth.uid() is not null);

comment on policy students_no_student_write on students is
  'Restrictive: student sessions (no auth.uid()) cannot write student rows. '
  'Redundant with the absence of a permissive policy, deliberately — this makes '
  'the denial explicit and survives a future permissive policy being added.';
