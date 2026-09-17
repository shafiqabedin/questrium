# ADR 0002 — No team penalties for an individual's behavior

**Status:** Accepted · **Date:** 2026-09-17

## Context

In Classcraft, when a student's HP reaches zero and they fall in battle, their
teammates also take a penalty — historically a loss of XP. This is the mechanism
that produces peer accountability: your teammates have a stake in keeping you on
task, so they help.

It works. It is also the most criticized mechanic in the product, and the
criticism is substantive.

## Problem

**It penalizes children for something they did not do.** A nine-year-old losing
XP because a classmate talked out of turn learns that the system is arbitrary.
Fourth graders are acutely sensitive to fairness; this reliably produces
grievance.

**It lands hardest on students who can least control the behavior.** A student
with ADHD, an anxiety disorder, or an IEP loses HP more often — frequently for
behavior that is a symptom, not a choice. Under a team-penalty rule, that student
becomes the reason their team keeps losing points. The mechanic converts a
disability into a social liability, in public, in front of the peer group that
matters most to them.

**The peer pressure it creates is not reliably kind.** "Help your teammate" and
"resent your teammate" produce identical incentives on paper. Which one shows up
depends on the children, and we do not get to choose.

## Decision

**Questrium ships with no team penalty for an individual student's fall.** No
shared HP loss, no shared XP loss, no shared consequence.

We get the same peer accountability through positive incentives instead:

- A Mender earns XP for a successful **Rally** on a fallen teammate
- A Guardian earns XP for **Shielding** a teammate from an HP loss
- A Sage earns XP for **Sharing Energy** that a teammate then spends
- Teams earn shared XP for team-wide teacher awards and for team goals

The structural incentive to look after your teammates is preserved: helping is
still the most XP-efficient thing a student can do. What changes is that the
system never blames a child for a classmate's behavior.

Supporting decisions:
- **XP never decreases** — it is a record of effort, not a balance to be raided
- **Per-student HP-loss multipliers**, teacher-configured and invisible to other
  students, so an accommodation does not become a visible label
- **Falling is private** — the student, their team, and the teacher see it.
  Never the projector

## If the teacher disagrees

She may want team consequences; teachers have professional reasons we should take
seriously, and she knows these children. If so: we discuss it, and if she still
wants it, it ships as an off-by-default, per-class configuration option with this
ADR linked from the settings screen. Her classroom, her call — but the default
carries the argument.

## Consequences

Positive: the sharpest ethical objection to this genre is designed out rather
than mitigated. Easier to get school approval. Students with IEPs are not made
into team liabilities.

Negative: weaker peer enforcement than the punitive version, if peer enforcement
was the goal. We are betting that positive incentives get most of the benefit,
and we should watch the pilot to see whether that bet holds.
