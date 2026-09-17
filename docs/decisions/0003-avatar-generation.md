# ADR 0003 — Avatar art via local SDXL, pre-rendered

**Status:** Accepted · **Date:** 2026-09-17

## Context

Students customize a character's appearance. We need a diverse avatar library —
enough that every child in the class can build someone who looks like them —
without licensing risk and without ongoing cost. Available hardware: 16 H100 GPUs
(8 × 2 nodes).

## Options considered

**Hosted image generators (Bing/DALL·E, Midjourney, OpenArt, Leonardo).**
Rejected. Free tiers almost universally restrict commercial use or leave output
ownership ambiguous, and an open-source repo means we are redistributing the
images. Midjourney's character reference is the best available but costs money
and its rights are tied to a paid tier. Depending on a hosted TOS for the visual
identity of a public project is a standing risk.

**CC0 asset packs (Kenney, OpenGameArt, itch.io).** Viable fallback.
Unambiguously licensed and immediate, but limited diversity of skin tones and
body types, and a generic look.

**Local SDXL.** Chosen.

## Decision

Generate the avatar library locally with SDXL on the available H100s.

**License:** SDXL weights are CreativeML-OpenRAIL-M. We own the outputs and may
commit and redistribute them. No hosted-service terms to comply with.

**Pre-rendered combinations, not runtime layering.** SDXL does not produce
cleanly registered layers — a separately generated shirt will not align with a
separately generated body. Since generation is effectively free on this hardware,
we render the combinations and ship PNGs rather than fighting alpha channels and
registration.

**Character consistency:** IP-Adapter FaceID for the baseline, plus a small
per-character LoRA (15–20 images, roughly 10 minutes on one H100) for the
canonical characters students see constantly.

**Visual coherence:** a style LoRA trained on 20–30 hand-picked outputs, so the
set looks like one game rather than one prompt. This matters more than any single
image's quality.

**Scope:** 3 classes × 4 body types × 5 skin tones as bases, plus outfit, hair,
and accessory variants. Diversity across skin tones and body types is a
requirement, not an enhancement.

**No runtime generation, ever.** The app has no GPU dependency, no API cost, and
no path by which a student sees an unreviewed image.

**Review gate:** every image is reviewed by the developer and the teacher before
it is committed. This is the entire content-safety story for avatars, and it is
far stronger than moderating generated output in front of nine-year-olds.

**Layout:**
```
tools/avatar-gen/          generation scripts, prompts, LoRA configs (in repo)
tools/avatar-gen/out/      raw output (gitignored)
public/avatars/            reviewed, approved sprites (committed)
```

## Consequences

Positive: zero licensing ambiguity, zero recurring cost, full control over
diversity and style, no runtime moderation risk, and the app works with no GPU.

Negative: an upfront art-production effort, and the sprite set is finite — adding
a new outfit means regenerating and re-reviewing rather than a prompt at runtime.
Committed PNGs add repository weight; if it becomes a problem, move to Supabase
Storage or Git LFS.

Fallback: if local SDXL proves impractical, CC0 asset packs ship a working
version and generated art replaces them later.
