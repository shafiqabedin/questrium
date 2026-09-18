# Changelog

Notable changes per tagged version. See [`docs/BLUEPRINT.md`](docs/BLUEPRINT.md)
§9 for the roadmap ahead.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning per [ADR 0004](docs/decisions/0004-versioning-and-release.md).

## [Unreleased]

### Added
- Database schema: teachers, classes, students, teams, behaviours, and an
  append-only point ledger (`supabase/migrations/0001`–`0006`)
- Row Level Security policies with column-scoped views: `classmates_public`,
  `teammates`, and a projector-safe `class_display` that contains no health data
  by construction
- `create_class`, `add_student`, `set_student_pin`; join-code generation that
  avoids characters nine-year-olds misread off a projector
- HP loss is a per-class config flag, so a purely positive economy needs no
  migration
- RLS test suite — 38 assertions covering teacher isolation, student read scope,
  write denial, the PII cap, and append-only enforcement (`supabase/tests/`)
- `docs/DEVELOPMENT.md` — conda Node env, since this machine has no system Node
- Master blueprint (`docs/BLUEPRINT.md`) — mechanics, principles, architecture,
  privacy posture, roadmap
- `CLAUDE.md` working agreement
- ADR 0001 — copyright boundary with Classcraft
- ADR 0002 — no team penalties for an individual's behavior
- ADR 0003 — avatar art via local SDXL, pre-rendered
- ADR 0004 — trunk-based development with tagged classroom releases
- README, MIT license, repository scaffolding
