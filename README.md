# Claude working-setup bundle — portable

A carry-over of the agent working setup from another machine: global working
rules, one personal skill, a session-start tooling-rot hook, and a settings
template. Everything here is **generic craft** — no employer, client, private
repo, or internal tooling is referenced. See [EXCLUDED.md](EXCLUDED.md) for what
was deliberately left behind and why.

## How to use it

Copy this directory to the new machine, open Claude Code in it, and say:

> Read README.md and INSTALL.md in this directory and set up this machine.

The agent will do the install. Or run the steps yourself from
[INSTALL.md](INSTALL.md) — there are only four, and none of them overwrite an
existing config without asking.

## What's in it

| File | Goes to | What it does |
|---|---|---|
| `home/CLAUDE.md` | `~/.claude/CLAUDE.md` | The working rules — visual-first decisions, denominator checks, trail markers, PR-review verdicts, repo conventions, standard workflow |
| `home/skills/visual-decisions/` | `~/.claude/skills/` | Personal skill: render a visual before any non-trivial decision, with a latency/cost level dial |
| `home/hooks/tooling-rot-siren.sh` | `~/.claude/hooks/` | SessionStart hook: catches degraded local tooling (missing/disabled plugin, stale marketplace checkout, CLI-vs-plugin version skew) before work starts |
| `home/hooks/rot-watch.example.json` | `~/.claude/hooks/` | Watchlist config for the siren. No config = silent. |
| `home/settings.template.json` | merge into `~/.claude/settings.json` | Model, effort, theme, notifications, empty-by-design permissions, plugin list, hook wiring |
| `home/memory/` | `~/.claude/projects/<project>/memory/` | Seed memory: the visual-learner fact |

## The two ideas worth keeping even if you drop the rest

**Visual before decision.** Prose-only option lists lose the consequences. Every
non-trivial decision gets a picture first — with a level dial so it never adds
latency to small questions. That dial is the part that makes it survive; the
first version without it was abandoned for being slow.

**A zero denominator is an abstention, not a pass.** "0 files checked ✓" is not
green, it's a gate that didn't run. This is a targeted habit for load-bearing
gates, not a mandate to distrust every exit code. The siren hook is the
mechanical version of the same idea, scoped to local tooling health.
