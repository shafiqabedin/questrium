# Questrium

A cooperative classroom role-playing game for 4th grade.

The teacher awards points for real classroom behavior. Students belong to small
teams with complementary, deliberately incomplete abilities — nobody can heal
themselves, nobody has enough energy alone — so helping each other is the only
way anyone's powers work. Points cash out into real classroom privileges.

**Status:** early design. Nothing works yet.

## Documentation

| | |
|---|---|
| [`docs/BLUEPRINT.md`](docs/BLUEPRINT.md) | The master design document. Start here |
| [`docs/decisions/`](docs/decisions/) | Architecture decision records |
| [`CLAUDE.md`](CLAUDE.md) | Working agreement for AI-assisted development |
| [`CHANGELOG.md`](CHANGELOG.md) | What shipped, per version |

## Design commitments

A few things this project will not do, explained at length in the blueprint:

- **No student is penalized for another student's behavior.** No team HP or XP
  penalties — the mechanic most likely to turn a struggling child into their
  team's liability. Peer accountability comes from rewarding help instead
  ([ADR 0002](docs/decisions/0002-no-team-punishment.md))
- **Health loss is never public.** Recognition goes on the projector; deficit
  does not
- **No player-versus-player.** Every power is self- or ally-directed
- **Minimal data.** A first name and a last initial. No email, no password, no
  photo, no free text authored by a child
- **Cosmetics never buy power**

## Stack

React 19 · TypeScript · Vite · Tailwind · Supabase (Postgres, Auth, Realtime) ·
Cloudflare Pages. Free at classroom scale.

## Inspiration

Questrium is openly inspired by [Classcraft](https://www.classcraft.com), which
demonstrated that this genre works in a real classroom. Game mechanics are not
copyrightable; expression is. Questrium shares structural ideas and none of
Classcraft's names, art, text, or code — see
[ADR 0001](docs/decisions/0001-copyright-and-originality.md) for the boundary we
hold. Not affiliated with or endorsed by Classcraft or HMH.

## License

MIT — see [LICENSE](LICENSE).
