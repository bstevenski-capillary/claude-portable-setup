# claude-portable-setup Knowledge Map

## About This Project

A portable bundle of a Claude Code working setup — **not an application**. It has
no build step, no package manager, and no runtime of its own. `home/` mirrors the
target machine's `$HOME`; installing means copying files out of it. The shipped
artifacts are three bash hooks, one skill, two rules files, a settings template,
and memory seeds.

Harness adoption level: `load-bearing-minimum`.

## Documentation

| File | What it holds |
|---|---|
| `CLAUDE.md` | **The detailed knowledge map** — repo thesis, load-bearing invariants, gate commands, editing conventions. Read it first. |
| `INSTALL.md` | The executable install spec, written to be carried out by an agent. |
| `EXCLUDED.md` | What was deliberately left out of the bundle, and why. |
| `README.md` | What the bundle contains, for a human browsing it. |
| `docs/changes/` | Per-change specs and implementation plans. |

`CLAUDE.md` carries the depth here rather than deferring to this file, because
its audience is the agent editing the bundle. This map exists to route the other
agents that read `AGENTS.md` by convention.

## Source Layout

There is no `src/`. The three layers named in `harness.config.json` are:

| Layer | Path | What it is |
|---|---|---|
| `hooks` | `home/hooks/**` | Shipped bash hooks — deployed to `~/.claude/hooks/`, run with no clone present |
| `tools` | `tools/**` | Repo-local scripts that operate *on* an install; never deployed |
| `tests` | `tests/**` | Flat bash suites of `ok`/`bad` assertions; no framework |

Bash files here are standalone — nothing `source`s anything else, so the layer
rules encode invocation and deployment reality rather than import graphs.

## Architecture

There is no `docs/architecture.md`. The architectural commitments live in
`CLAUDE.md` under "The idea the whole repo encodes" and "Load-bearing invariants",
each row of which is a shipped bug pinned by a test.

The one-line version: **a zero denominator is an abstention, not a pass.**
