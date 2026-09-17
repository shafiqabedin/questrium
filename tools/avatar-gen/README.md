# Avatar generation

SDXL pipeline for the avatar sprite library. Runs locally on the H100 nodes; see
[ADR 0003](../../docs/decisions/0003-avatar-generation.md) for why local and why
pre-rendered.

**Not built yet** — scheduled for v0.5.0 (blueprint §9).

## Planned setup

Python tooling here *does* want a virtualenv, unlike the rest of the repo:

```bash
python -m venv .venv
source .venv/bin/activate
pip install torch diffusers transformers accelerate peft rembg
```

`.venv/`, `models/`, and `out/` are gitignored. Only reviewed sprites are
committed, to `public/avatars/`.

## Review gate

Every image is reviewed by the developer and the teacher before commit. There is
no runtime generation and no path by which a student sees an unreviewed image.
This is the whole content-safety story for avatars, and it is deliberate.
