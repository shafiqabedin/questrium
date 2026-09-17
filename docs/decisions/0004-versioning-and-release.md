# ADR 0004 — Trunk-based development with tagged classroom releases

**Status:** Accepted · **Date:** 2026-09-17

## Context

The design will change frequently, driven by sessions with a 4th-grade teacher
and by what happens in an actual classroom. We need to know which version a
class was using when feedback arrives, and be able to return to a version that
worked.

## Decision

**Trunk-based development.** One long-lived branch, `main`, always deployable.
Feature branches are short-lived (`feat/`, `fix/`, `docs/`) and merge within days.

**Semver tags mark classroom-testable versions.** `v0.1.0`, `v0.2.0`, … Each tag
is something the teacher can actually try, and each is a rollback point. If
v0.3.0 worked and v0.4.0 confuses the class, we go back to the tag.

- `MINOR` — a new roadmap version (blueprint §9)
- `PATCH` — fixes to a version already in classroom use
- `v1.0.0` — survived a full term with real students

**Design intent is versioned separately from code:**

```
docs/BLUEPRINT.md              current intended design — always up to date
docs/decisions/NNNN-*.md       decisions with lasting rationale (ADRs)
docs/design-iterations/        dated raw notes from teacher sessions
CHANGELOG.md                   what shipped per tag
```

`docs/design-iterations/` is where a teacher session lands verbatim, before it is
folded into the blueprint. It answers "why did we change this in November?" six
months later, which the blueprint alone cannot — the blueprint holds the current
design, not its history.

**ADRs are never deleted.** A reversed decision gets a new ADR and the old one is
marked `Superseded by NNNN`. The reasoning we abandoned is often the most useful
thing in the file.

**Rejected: long-lived version branches.** They would let an old version keep
running for one class while the next is built, but with one class and one
developer that is merge overhead for a problem we do not have. Tags give us
rollback without the maintenance.

**Rejected: docs-only versioning.** Tracing design intent without being able to
run the version it describes is half a solution.

## Consequences

Positive: standard and simple, clean rollback, feedback maps to a specific
version, and design history is preserved without branch overhead.

Negative: no parallel maintained versions — if two classes ever need different
versions simultaneously, this needs revisiting. Requires discipline that `main`
stays deployable and that the blueprint is updated in the same commit as the
change it describes.
