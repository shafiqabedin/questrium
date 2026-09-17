# CLAUDE.md — Working agreement for Questrium

Instructions for Claude Code working in this repository. Read `docs/BLUEPRINT.md`
before making design-affecting changes.

---

## What this project is

A cooperative classroom RPG layer for **one 4th-grade class** — roughly 25
students aged 9–10, and their teacher. The teacher awards points for real
classroom behavior; students on small teams hold complementary powers that only
work on each other; points cash out into real classroom privileges.

**The users are nine years old.** That is the primary design constraint on
everything, not a footnote.

---

## Non-negotiables

These come from `docs/BLUEPRINT.md` §4 and §7. Do not violate them, and do not
"temporarily" violate them to get something working. If a task appears to require
breaking one, stop and say so.

1. **No student PII beyond a first name and last initial.** No email, no
   birthdate, no photo, no free-text authored by a student. Adding a field that
   collects more is a blueprint change, not an implementation detail.
2. **HP loss and falling are never shown publicly.** Not on the projector view,
   not in any all-class list, not in a team view visible during a lesson. Visible
   to that student, their team, and the teacher — nowhere else.
3. **No student is penalized for another student's behavior.** No team HP or XP
   penalties. If asked to add one, point at §4.3 and confirm before building it.
4. **No PvP, no negative targeting.** Every power is self- or ally-directed.
   There is no attack, no debuff, no stealing.
5. **GP buys cosmetics only.** Never power, never HP, never privileges.
6. **XP never decreases.**
7. **Point changes are reversible and append-only.** Undo writes `undone_at`; it
   never deletes a row from `point_events`.
8. **No third-party analytics, ads, or tracking.** No exceptions, no "just for
   debugging."
9. **Awarding a point stays under three seconds on a phone.** If a change adds
   taps or a confirmation dialog to that path, flag it.
10. **Nothing pedagogically meaningful is hardcoded.** Numbers, behavior lists,
    consequences, privileges, and rules live in the database as teacher config.

---

## Tech stack

Use what is here. Do not introduce a new library, framework, or service without
asking — this project's constraint is fast iteration by a small team, and every
dependency works against that.

- **Frontend:** React 19, TypeScript (strict), Vite, Tailwind CSS
- **Backend:** Supabase — Postgres 15, Row Level Security, Auth, Realtime,
  Edge Functions (Deno)
- **Hosting:** Cloudflare Pages (static). *Not* Vercel — its free tier forbids
  commercial use; Cloudflare Pages does not
- **Avatar generation:** SDXL locally on H100 nodes, `tools/avatar-gen/`
- **Testing:** Vitest for units, Playwright for end-to-end

### Stack rules

- TypeScript `strict` stays on. No `any` — use `unknown` and narrow it
- No `as` casts to silence a type error; fix the type
- Database types are generated from the schema (`npm run db:types`), never
  hand-written. Regenerate after a migration
- Server-side authorization is Row Level Security. UI-side checks are a
  convenience for the user, never the security boundary
- Every schema change is a numbered migration in `supabase/migrations/`. Never
  edit an applied migration; add a new one

---

## Code conventions

- **Components:** function components, hooks only. No class components
- **Files:** `PascalCase.tsx` for components, `camelCase.ts` for everything else
- **Directories:** `src/features/<feature>/` groups by feature, not by file type.
  Shared UI in `src/components/`, shared logic in `src/lib/`
- **Game rules live in `src/lib/rules/`** as pure functions, separate from React.
  They must be unit-testable without a database or a browser
- **Data access goes through `src/lib/api/`.** No Supabase client calls scattered
  through components
- **Comments explain why, not what.** Match the density of the surrounding file
- **No premature abstraction.** Two call sites is not a pattern; three might be

### Accessibility and age-appropriateness

Student-facing UI, every time:
- Tap targets at least 44×44 px, prefer 56 for primary actions
- Interface text at a 2nd–3rd grade reading level. Short sentences. Avoid
  "unavailable", "insufficient", "authenticate" — say "not enough energy yet"
- Never use color alone to carry meaning; pair it with an icon or a label
- Nothing requires typing beyond a class code and a 4-digit PIN
- Assume a slow, shared Chromebook on flaky school Wi-Fi

---

## Working style for this repo

### Before starting

- **Read the blueprint** for anything touching game rules, data model, or
  privacy. Do not infer the design from the code — the blueprint is the source
- Check `docs/decisions/` for an ADR covering the area. If a change contradicts
  an ADR, that is a conversation, not a commit
- For a non-trivial feature, plan first and get sign-off. The design is expected
  to churn based on teacher feedback; wasted implementation is the main cost risk

### While working

- One concern per commit
- Update `docs/BLUEPRINT.md` in the same commit when the design changes. A
  blueprint that lags the code is worse than no blueprint
- Write an ADR when a decision has a rationale worth remembering in six months
- Run `npm run check` (types, lint, tests) before saying something is done
- Report honestly. If tests fail, say so and show the output. If something is
  half-done, say which half

### Do not

- Add a dependency without asking
- Add a feature that is not in the current roadmap version
- "Improve" game balance numbers unasked — those belong to the teacher
- Refactor beyond the task at hand
- Commit or push unless asked
- Commit generated avatar images without the review gate in §8 of the blueprint

---

## Git and versioning

Trunk-based. `main` is always deployable.

- Feature branches: `feat/<short-name>`, `fix/<short-name>`, `docs/<short-name>`
- Short-lived — merge to `main` within days, not weeks
- Tag each classroom-testable version: `v0.1.0`, `v0.2.0`, …
  Roadmap in blueprint §9, shipped notes in `CHANGELOG.md`
- Tags are the rollback points. If the teacher liked v0.3.0 and v0.4.0 confuses
  the class, we return to the tag

### Commit messages

```
<area>: <what changed, imperative>

<why, if not obvious>
```

Areas: `docs`, `schema`, `auth`, `points`, `powers`, `avatars`, `projector`,
`teacher`, `student`, `infra`, `test`.

End commit messages with:
```
Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
```

End pull request descriptions with:
```
🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

---

## Copyright boundary

Questrium is inspired by Classcraft. Mechanics are not copyrightable; expression
is. See `docs/decisions/0001-copyright-and-originality.md`.

**Fine to reuse:** the HP/AP/XP structure, asymmetric cooperative classes, a
consequence on reaching zero health, privilege-based rewards, team structure.

**Never reuse:** the name "Classcraft", their art or icons, their UI layouts,
their power names, or any of their text. Do not copy code from any Classcraft
clone repository. When naming anything, pick our own name — we use
Guardian/Sage/Mender, not Warrior/Mage/Healer.

If you notice something in this repo that looks copied from Classcraft, say so.

---

## Testing expectations

- **Game rules in `src/lib/rules/` need unit tests.** These encode fairness, and
  a bug here means a child is treated unfairly by a machine. Cover the edges:
  HP at exactly 0, AP below a power's cost, level-up boundaries, undo of an event
  already undone
- **Row Level Security needs tests.** Prove a student cannot read another team's
  data and cannot write their own stats. Do this against a real database, not mocks
- **The award path needs an end-to-end test**, including undo
- UI polish does not need tests. Anything touching a number a student sees does

---

## Things that will come up

**"Can we add a leaderboard?"** — Ranking nine-year-olds against each other
conflicts with §4.1. Team progress or class-wide goals, yes. Student ranking, no.
Ask before building it.

**"Can the teacher take HP from a whole team?"** — Blueprint §4.3. Raise it,
don't just build it.

**"Let's show everyone's HP on the projector."** — §4.2. No.

**"Let students name their own character."** — Free text authored by a child,
visible to other children, is a moderation problem and a COPPA question. Not in
v1; needs a decision, not an implementation.

**"Let's generate avatars on demand with an API."** — Unreviewed images in front
of nine-year-olds. Blueprint §8: the library is fixed and pre-approved.

**"The free tier paused our database."** — Supabase pauses free projects after 7
days idle, which will happen over a school break. One click to restore. Do not
re-architect around it; note it on the term-start checklist.
