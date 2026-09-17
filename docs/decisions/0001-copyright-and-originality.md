# ADR 0001 — Copyright boundary with Classcraft

**Status:** Accepted · **Date:** 2026-09-17

## Context

Questrium is openly inspired by Classcraft (Shawn Young, 2013; acquired by
Houghton Mifflin Harcourt, 2021). It will be open source and public. We need a
boundary we can state plainly and hold to, rather than a vague intention to be
different.

## Decision

We rely on the separation between mechanics and expression.

**Game mechanics, rules, and systems are not protected by copyright.** Copyright
protects the expression of an idea, not the idea, system, or method of operation
(17 U.S.C. §102(b); *Baker v. Selden*). Board and video game rules have
repeatedly been held unprotectable. So the structural design is ours to use.

**Reusable — the mechanics:**
- A health / energy / experience point triad
- Asymmetric cooperative character classes with complementary abilities
- Losing health for off-task behavior; a real-world consequence at zero
- Spending an energy resource to use abilities
- Experience-driven levels that unlock abilities
- A cosmetic currency separated from the power economy
- Team structure with shared stakes
- Real-world classroom privileges as rewards
- Random class-wide events
- Class-versus-boss quiz review

**Not reusable — the expression:**
- The name "Classcraft", its logo, or any confusingly similar mark
- Any artwork, icon, avatar, or sprite
- UI layouts and visual designs copied screen-for-screen
- Their specific power names, ability descriptions, or interface copy
- Their code, or code from any Classcraft clone repository

**Concrete consequences:**
- Classes are **Guardian / Sage / Mender**, not Warrior / Mage / Healer. The
  latter are generic RPG terms and probably safe, but our own names cost nothing
  and remove the argument
- Powers get our own names and our own descriptions, written from scratch
- All art is generated or licensed by us (see ADR 0003)
- The README states the inspiration openly. Acknowledging influence is honest and
  is not an admission of infringement

**Trademark:** "Questrium" needs a USPTO search and a domain check before any
public launch. Tracked in blueprint §10.

**Our license:** MIT. Permissive, standard for a project meant to be adopted by
other teachers.

## Consequences

Positive: a clear line anyone can check, and no dependency on Classcraft's assets
or terms. Naming things ourselves also produces a better fit for 4th grade than
inherited terminology.

Negative: we cannot point at Classcraft's UI as a spec, so more design work falls
on us and the teacher. That work was needed anyway.

## Notes

This is engineering judgment, not legal advice. If Questrium ever moves toward
commercial distribution, get an actual lawyer to look at it.
