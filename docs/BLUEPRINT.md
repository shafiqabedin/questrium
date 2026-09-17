# Questrium — Master Blueprint

**Status:** Draft v0.1 · **Last updated:** 2026-09-17
**Owner:** Shafiq Abedin · **Design advisor:** 4th-grade classroom teacher (TBD name)

This is the single source of truth for what Questrium is and why. Every design
decision either lives here or in `docs/decisions/` as an ADR. If code and this
document disagree, that is a bug in one of them — resolve it explicitly.

---

## 1. What Questrium Is

A cooperative classroom role-playing layer for a single 4th-grade class.

The teacher awards and deducts points based on real classroom behavior. Students
belong to small teams whose members hold complementary, deliberately incomplete
abilities, so helping each other is the only way any of them can use their
powers. Points cash out into real-world classroom privileges.

Questrium is **not** an educational content game. It teaches nothing directly.
It is an incentive and social-structure layer around whatever the teacher is
already teaching.

### Design lineage and independence

Questrium is inspired by Classcraft (Shawn Young, 2013; acquired by HMH 2021).
Game *mechanics* are not copyrightable; *expression* is. See
`docs/decisions/0001-copyright-and-originality.md` for the specific boundary we
hold. In short: we may reuse the structural ideas (a health/energy/experience
triad, asymmetric cooperative classes, a real-world consequence on reaching zero
health, privilege-based rewards). We may not reuse Classcraft's name, art, UI
layouts, power names, or copy.

---

## 2. Players and Context

| | |
|---|---|
| **Primary users** | One 4th-grade teacher, ~20–30 students aged 9–10 |
| **Secondary** | Possibly parents (read-only), possibly other teachers later |
| **Setting** | A single classroom, in-person, one school year |
| **Devices** | Teacher: laptop + phone. Students: shared Chromebooks/tablets, possibly 1:1, possibly home access |
| **Scale target** | 1 class for the pilot. Design must not *prevent* multi-class later, but must not pay for it now |

### The age constraint drives everything

Nine-year-olds are the hard design constraint, not a detail:

- **Reading level.** Interface text at roughly a 2nd–3rd grade reading level.
  Icons and color carry meaning alongside words, never instead of them.
- **No typing of anything long.** Class codes, PINs, and taps. Never an email
  address, never a password they must remember and type.
- **Motor precision.** Large tap targets (minimum 44×44 px, prefer 56).
- **Fairness sensitivity.** This age group is acutely attuned to fairness. Any
  mechanic that can be perceived as arbitrary punishment will generate conflict.
- **Legal.** Under 13 means COPPA applies. See §7.

---

## 3. Core Mechanics

These are the mechanics for v1. Numbers are starting points to be tuned with the
teacher, not fixed values — every one of them lives in a config table, not in code.

### 3.1 The point triad

| Stat | Direction | Earned/lost by | Purpose |
|---|---|---|---|
| **HP** (Health) | Lost, regained | Lost for off-task behavior; regained by Healers and overnight | The consequence channel |
| **AP** (Action Points) | Spent, regenerated | Spent casting powers; regenerates daily | The rate limiter on powers |
| **XP** (Experience) | Only gained | Positive behavior: helping, participation, work turned in | Progression → levels → new powers |
| **GP** (Gold) | Gained, spent | Gained alongside XP; spent on avatar cosmetics only | Cosmetic sink, firewalled from power |

**XP never decreases.** This is a deliberate departure from Classcraft, whose
team penalty on a fall removes XP from teammates. Rationale in §4.3.

**GP buys only cosmetics.** Never powers, never HP, never privileges. A student
who spends nothing is never mechanically weaker.

### 3.2 Character classes

Three classes, chosen by the student at the start (changeable once per term with
teacher approval). Stats are asymmetric so that no student can operate alone.

| Class | HP | AP | AP regen | Role |
|---|---|---|---|---|
| **Guardian** | High (100) | Low (20) | Slow (+5/day) | Absorbs HP loss on a teammate's behalf |
| **Sage** | Low (60) | High (40) | Fast (+15/day) | Grants AP to teammates so they can cast |
| **Mender** | Medium (80) | Medium (30) | Medium (+10/day) | Restores HP; revives a fallen teammate |

Class names are ours, deliberately not Warrior/Mage/Healer, to keep visible
distance from the source. (Mechanically identical; that part is fine.)

**The asymmetry is the point.** A Guardian runs out of AP and needs a Sage. A
Sage has too little HP to survive alone and needs a Guardian. Nobody heals
themselves. Cooperation is structural, not encouraged by a poster on the wall.

### 3.3 Powers

Unlocked by level, cost AP, and split into two kinds:

**Game powers** act inside the system and target *other students*:
- *Shield* (Guardian) — take the next HP loss a teammate would take
- *Share Energy* (Sage) — transfer AP to a teammate
- *Mend* (Mender) — restore HP to a teammate
- *Rally* (Mender) — revive a fallen teammate

**Privilege powers** cash out into real classroom perks, defined by the teacher:
- Examples: choose your seat for a day, music while working, hand in one
  assignment a day late, one hint on a quiz, pick the read-aloud book
- The teacher defines the full list. Questrium ships suggestions, not rules.
- Every privilege cast creates a request the teacher approves or declines, so the
  teacher is never surprised by a student asserting a privilege.

**No power targets a student negatively.** There is no attack, no debuff, no PvP.
Every power is self- or ally-directed. This is not an oversight to be fixed later.

### 3.4 Teams

Students are grouped into teams of 4–6, assigned by the teacher, containing a mix
of classes. Teams are the unit of cooperation:

- A team is visible to its members: their HP, AP, level, and whether anyone has fallen
- Powers can only target teammates (v1; teacher can widen this later)
- Teams can earn shared XP from team-wide teacher awards

Teams should be reshuffled periodically (the teacher decides when) so social
groups do not calcify.

### 3.5 Falling and its consequence

When a student's HP reaches 0, they have **fallen**.

- They cannot cast powers until revived
- The teacher is notified
- A **consequence** is drawn from the teacher-configured consequence list
- A Mender teammate can *Rally* them, or they recover overnight

The consequence list is entirely the teacher's. Questrium ships a starting set of
mild, restorative suggestions (help tidy the room, a short reflection sheet,
explain the rule you broke to the teacher) and explicitly does **not** ship
punitive options. Whether a randomized "wheel" is used at all is the teacher's
call — see ADR 0002.

### 3.6 Random events

An optional daily event affecting the whole class, drawn from a teacher-editable
list. Purely additive in v1: "everyone gains 20 XP", "all Sages regain full AP".
No event removes HP. Variance makes the system feel alive; punitive randomness
makes it feel unfair, and to a nine-year-old that distinction is enormous.

### 3.7 Deferred to later versions

Not in v1, but the data model should not make them painful:
- **Boss battles** — class-vs-boss framing for quiz review
- **Quests** — teacher-authored branching objective maps
- **Pets/mounts**
- **Parent read-only view**
- **Multiple classes / multiple teachers**
- **Volume meter**

---

## 4. Design Principles

These are the commitments that outlive any particular feature. When a change
conflicts with one of these, that is a decision worth an ADR, not a quick edit.

### 4.1 Interdependence over competition
Powers are other-directed. There is no PvP, no class leaderboard ranking
students against each other, no scarcity that makes one student's gain another's
loss. Students should want their teammates to do well.

### 4.2 Recognition is public; deficit is private
Anything positive — XP, levels, achievements — may be shown on the projector.
**HP loss and falling are never displayed publicly.** A student's low health is
visible to the student, their team, and the teacher. It never goes on the big
screen. Nine-year-olds do not need an audience for their worst moments.

### 4.3 No student is punished for another student's behavior
Classcraft's team-XP penalty on a fall is the mechanic we most deliberately
reject. It manufactures peer pressure, and it lands hardest on students with
ADHD, anxiety, or IEPs — the students least able to control the behavior being
penalized, who then absorb their teammates' resentment for it.

We get peer accountability the positive way instead: teammates are rewarded for
*preventing* and *repairing* falls (a Mender earns XP for a successful Rally; a
Guardian earns XP for Shielding). The incentive to look after your teammates is
identical. The blame is not.

If the teacher wants team consequences, that is their professional call and we
will discuss it — but the default ships off, and this section explains why.

### 4.4 The teacher is the game master
Every number, list, rule, and consequence is configurable. Classroom norms vary
enormously and we are building for one teacher we can actually ask. Nothing
pedagogically meaningful is hardcoded.

### 4.5 Awarding points must take under three seconds
This is the make-or-break usability constraint. A teacher mid-lesson, holding a
phone, must be able to award or deduct in one or two taps from preset behaviors.
If it takes longer, the tool goes unused and every other feature is irrelevant.
This constraint outranks visual polish and outranks feature count.

### 4.6 Cosmetics are firewalled from power
GP buys appearance. XP and AP drive capability. The two economies never touch.

### 4.7 Undo everything
Teachers misclick, especially while teaching. Every point change is reversible
from a recent-activity list, and the audit trail keeps the correction. A tool
that punishes a child because of a mis-tap is worse than no tool.

### 4.8 Degrade gracefully
The classroom Wi-Fi will fail. The projector view must survive a network blip,
and the teacher must be able to award points offline with the changes syncing
later.

---

## 5. Known Risks

Recording these so we design against them rather than rediscovering them in a
classroom.

| Risk | Mitigation |
|---|---|
| **Extrinsic motivation crowds out intrinsic** | Keep XP tied to effort and helping, not to correct answers or grades. Never tie the game to academic scores |
| **Public shaming via HP** | §4.2 — deficit is private, structurally not just by convention |
| **Peer resentment toward struggling students** | §4.3 — no team penalties. Positive-only peer incentives |
| **Inequity for students with IEPs/ADHD** | Per-student HP-loss multipliers and exempt behaviors, teacher-configured, invisible to other students |
| **Teacher burnout on point-awarding** | §4.5 — presets, one-tap, phone-first. Measure it and ask |
| **Privileges favor already-compliant students** | XP for effort and helping, which any student can do, not for compliance alone |
| **Novelty wears off by November** | Design for a term, expect to re-tune. Iteration versions are how we respond |
| **Free-tier service pauses over school breaks** | Documented in §6; a paid tier removes it if it bites |

---

## 6. Technical Architecture

Chosen for stability and for fast iteration under frequent design change, not for
scale we do not have.

```
Student / Teacher browser
  |
  |  static assets
  v
Cloudflare Pages ............ React 19 + TypeScript + Vite + Tailwind
  |
  |  HTTPS (PostgREST) + WebSocket (realtime)
  v
Supabase .................... Postgres 15 + Row Level Security
                              Auth (Google OAuth, teacher only)
                              Realtime (live projector + student views)
                              Edge Functions (student PIN login, deno)
                              Storage (avatar sprite sheets)
```

### 6.1 Why this stack

**Cloudflare Pages** for hosting, not Vercel. Vercel's free "Hobby" tier is
license-restricted to non-commercial use; Cloudflare Pages' free tier has no such
restriction, plus unlimited bandwidth and requests. The frontend is a static Vite
bundle talking straight to Supabase, so Vercel's serverless functions would go
unused — there is nothing to trade for accepting its restriction.

**Supabase** because it supplies Postgres, Google auth, row-level security, and
realtime subscriptions as one integrated free service. Given that this project
will see many design changes, the code we do not have to write and maintain
(auth flows, permission checks, websocket plumbing) is the main saving.

**React + TypeScript** because the design will change constantly and types catch
the breakage. **Tailwind** because restyling is fast and there is no separate
stylesheet architecture to keep in sync.

### 6.2 Costs and limits

| Service | Tier | Limits | Watch out for |
|---|---|---|---|
| Cloudflare Pages | Free | Unlimited bandwidth/requests, 500 builds/mo | None at this scale |
| Supabase | Free | 500 MB DB, 50k MAU, 1 GB storage | **Project pauses after 7 days of inactivity** — a real issue over school breaks. One click to restore; $25/mo Pro removes it |
| Google OAuth | Free | — | One-time client-ID setup in Cloud Console. No `gcloud` CLI needed, ever |
| SDXL avatar generation | Free | Local H100s | One-time generation, outputs committed to the repo |

Total recurring cost at pilot scale: **$0**.

### 6.3 Data model sketch

Tables (details will land in the schema migration, this is the shape):

```
classes         id, teacher_id, name, join_code, config_json, created_at
students        id, class_id, first_name, last_initial, pin_hash, class_type,
                level, hp, hp_max, ap, ap_max, xp, gp, avatar_json,
                hp_loss_multiplier, is_fallen
teams           id, class_id, name, crest
team_members    team_id, student_id
behaviors       id, class_id, label, icon, stat, delta, is_positive, sort_order
point_events    id, class_id, student_id, behavior_id, stat, delta,
                awarded_by, note, created_at, undone_at
powers          id, class_type, name, description, kind, ap_cost, level_req,
                target_scope
power_casts     id, caster_id, target_id, power_id, status, created_at,
                resolved_at, resolved_by
privileges      id, class_id, label, ap_cost, level_req, needs_approval
consequences    id, class_id, label, weight, is_active
random_events   id, class_id, label, effect_json, is_active
avatar_items    id, slot, name, gp_cost, level_req, sprite_path
student_items   student_id, avatar_item_id, acquired_at
```

Two things to note. **`point_events` is append-only** — an undo writes
`undone_at`, it never deletes. That is both §4.7 and the audit trail a school
will eventually ask about. And **`config_json` on `classes`** holds the tunable
numbers (starting HP by class, AP regen rates, XP per level curve, whether team
consequences are on) so the teacher can retune without a deploy.

### 6.4 Authentication

Two entirely separate paths, which is deliberate.

**Teacher — Google OAuth via Supabase Auth.** Standard, secure, no password for
us to store. One-time setup: register an OAuth client in the Google Cloud
Console (a web form, about five minutes) and paste the client ID and secret into
Supabase. `gcloud` is never involved.

**Student — class code plus PIN, no account.**

```
1. Student opens the join page
2. Types the class code the teacher displays        (e.g. FROG-7291)
3. Taps their name and avatar from a grid
4. Types a 4-digit PIN
   -> session token, scoped to that student, valid for the school day
```

No email, no password reset, no student-held credential to lose. The PIN is
bcrypt-hashed; the teacher can reset it in one click when a student forgets,
which they will. Rate-limited by class code to make guessing impractical.

Why this shape: it collects no PII beyond a first name and last initial, which
keeps us out of COPPA's verifiable-parental-consent requirement almost entirely,
and it means no district IT ticket to create 25 student accounts. It also works
on a shared Chromebook cart, which is the actual classroom.

Row Level Security enforces the boundaries in the database, not in the UI: a
student can read their own row and their teammates' public fields, and nothing
else. A teacher can read and write only their own class.

---

## 7. Privacy, Safety, and Compliance

### COPPA (under 13)
- Collect a first name and last initial. Nothing more. No email, no birthdate,
  no photograph, no free-text student-authored content in v1
- No third-party analytics, no advertising, no tracking pixels — ever
- Data stays in Supabase and Cloudflare; it is not sent anywhere else
- Because we collect no personal information beyond a classroom nickname, the
  verifiable-parental-consent requirement is largely avoided. This is a design
  choice, not an accident, and it should not be quietly eroded by a later feature

### FERPA
Behavior records are education records. Practically: the teacher owns and can
export their class's data, records are retained only for the school year plus
one, and no data is shared outside the class without the teacher's action.

### School approval
The teacher must confirm their school and district policy before any student
uses this, even with the minimal data above. Get it in writing. This is on the
launch checklist, not an afterthought.

### Student-to-student content
There is none in v1. No chat, no free text, no custom names. Communication is
limited to structured, pre-defined power casts. This eliminates the entire
moderation problem rather than trying to solve it with a word filter.

### Avatars
The avatar library is a fixed, finite set of images that the teacher and I review
and approve before it ships. Nothing is generated at runtime. There is no path by
which a student can produce an unreviewed image.

---

## 8. Avatar Pipeline

Locally generated with SDXL on the available H100 nodes. License is
CreativeML-OpenRAIL-M: we own the outputs and may commit and redistribute them,
with no hosted-service terms-of-service restriction to worry about. See
`docs/decisions/0003-avatar-generation.md`.

**Approach:** pre-rendered combinations, not runtime layering. SDXL does not
produce cleanly registered layers — a separately generated shirt will not line up
with a body. Since generation is effectively free on this hardware, render the
combinations instead and ship PNGs.

**Targets:** 3 classes × 4 body types × 5 skin tones as base characters, plus
outfit, hair, and accessory variants per base. A style LoRA trained on 20–30
hand-picked outputs keeps the whole set looking like one game rather than one
prompt, which matters more than any individual image's quality.

**Pipeline location:** `tools/avatar-gen/`. Generation scripts live in the repo;
generated sprites are committed under `public/avatars/` so the app has no
GPU dependency and no runtime cost.

**Review gate:** every image is reviewed by me and the teacher before commit.
Diversity across skin tones and body types is a requirement, not a nice-to-have —
every student in the class needs to be able to build an avatar that looks like
them.

---

## 9. Roadmap

Versions are tagged and correspond to something the teacher can actually try.
See `docs/decisions/0004-versioning-and-release.md`.

### v0.1.0 — Foundation
Repo, docs, schema, migrations, teacher Google login, class creation, student
roster entry. No game yet. **Done when:** the teacher can log in and create a
class with students in it.

### v0.2.0 — Point awarding
The behavior presets and the one-tap award UI, phone-first. HP/AP/XP/GP tracked.
Recent-activity list with undo. **Done when:** the teacher can award points to a
student in under three seconds on a phone, and undo it.

### v0.3.0 — Students can log in
Class code plus PIN join flow. Student dashboard showing their own stats and
their team. Class selection. **Done when:** a student can log in on a Chromebook
and see their own character.

### v0.4.0 — Powers
Power casting, AP costs, teacher approval queue for privileges. Falling and
Rally. **Done when:** a Mender can revive a fallen teammate and the teacher sees
the request.

### v0.5.0 — Avatars
The generated sprite library, GP shop, avatar customization.
**Done when:** a student can spend GP to change their character's appearance.

### v0.6.0 — Projector view
The class display: teams, levels, positive recognition. No HP shown (§4.2).
Random events. **Done when:** it can run on the classroom projector all day.

### v1.0.0 — Classroom pilot
Whatever survives contact with 25 nine-year-olds for a full term.

**Then, informed by the pilot:** boss battles, quests, parent view, multi-class.

---

## 10. Open Questions

To resolve with the teacher, tracked here until they become ADRs.

1. Does the school or district need to approve this, and in what form?
2. Do students have 1:1 devices, a shared cart, or neither? Home access?
3. What consequences does the teacher actually want on a fall — and does she want
   a randomized wheel at all, or a chosen consequence?
4. What privileges is she willing to give away? This list is the entire reward
   economy and it is hers to write
5. Are there students whose IEP or behavior plan needs specific accommodation in
   the HP rules?
6. Class period structure — how many times a day would she realistically award points?
7. Does she want HP loss at all, or would a purely positive economy work better
   for 4th grade? Worth genuinely asking; it may be the single biggest design fork
8. Team size and how often teams reshuffle?
9. What happens over a weekend and over a school break — full HP regeneration?

---

## 11. Document Conventions

- **This blueprint** holds the current intended design. Update it when the design
  changes; it should never describe something we have decided against
- **`docs/decisions/NNNN-*.md`** holds decisions with a rationale worth keeping,
  in ADR form. Superseded ADRs are marked superseded, never deleted
- **`docs/design-iterations/`** holds dated notes from teacher design sessions —
  raw input, before it is folded into this document
- **`CHANGELOG.md`** holds what shipped per tagged version
- **`CLAUDE.md`** holds the working agreement for AI-assisted development on this
  repo. It is instructions to Claude, not documentation for humans
