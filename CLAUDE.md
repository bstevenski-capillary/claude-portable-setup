# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A **portable bundle of a Claude Code working setup** — not an application. It has
no build step, no package manager, and no runtime of its own. `home/` is a mirror
of the target machine's `$HOME` layout; installing means copying files out of it
to `~/.claude/`, `~/.config/ai-rules/`, and `~/.claude/projects/<slug>/memory/`.
`INSTALL.md` is the executable spec for that copy — it is written to be *read and
carried out by an agent*, so treat it as the source of truth for install
behavior, not as prose docs.

The shipped artifacts are three bash hooks, one skill, two rules files, a
settings template, and memory seeds. Everything else (`README.md`, `INSTALL.md`,
`EXCLUDED.md`) explains or installs those.

`tools/` is the exception to "everything in this repo is cargo": it holds
repo-local scripts that operate *on* an install rather than shipping into one.
`check-drift.sh` lives there rather than in `home/hooks/` for a concrete reason
— checking drift requires the bundle to diff against, so it can only run from a
clone, which makes deploying it pointless.

## Commands

```bash
./tests/run-all.sh          # every suite (88 cases across 4)
./tests/test-siren.sh       # or one suite at a time
./tests/test-nudge.sh
./tests/test-statusline.sh
./tests/test-drift.sh
```

There is no test framework and no single-case filter — a suite is a flat bash
script of `ok`/`bad` assertions. To run one case, comment out the others or add a
temporary early `exit`.

The four gates for this repo (no CI; run them by hand before a PR):

```bash
bash -n home/hooks/*.sh tools/*.sh tests/*.sh         # syntax
shellcheck home/hooks/*.sh tools/*.sh                # lint — clean at default severity
shellcheck -S warning tests/*.sh                     # suites carry known SC2015 infos
python3 -m json.tool home/settings.template.json     # JSON parses
python3 -m json.tool home/hooks/rot-watch.example.json
./tests/run-all.sh                                   # test
```

The suites use `[ cond ] && ok ... || bad ...` deliberately (the assertion
helpers are total), which shellcheck flags as SC2015 *info*. Hooks must stay
clean at default severity; suites are gated at `-S warning`.

### Deploy drift — the check nothing else performs

The source of truth is `home/`, but the *running* config is `$HOME`. They
diverge silently the moment a merged change isn't re-installed:

```bash
./tools/check-drift.sh                     # 0 clean · 1 drift · 2 abstention
CHECK_ROOT=/tmp/fixture ./tools/check-drift.sh
```

Run it after merging anything under `home/`, and before trusting a session's
rules. Read-only by contract — it reports, never repairs, because the size of
the gap is the finding and a silent auto-fix erases it.

Exit **2 is not a failure and not a pass**: nothing of the bundle was installed
at the root, so nothing was compared. Keeping it distinct from 0 is what stops a
fresh clone reporting parity it never checked.

Two differences are expected and the tool encodes both: the absolutized line-6
`@import` (per INSTALL.md §1) and the machine-local `rot-watch.json` /
`.rot-npm-cache.json`. The import handling canonicalizes the *target* rather
than skipping the line — `tests/test-drift.sh` pins both halves, because a
blanket line-6 skip would wave through an import rewritten to point elsewhere,
which is the one edit that silently unloads every shared rule.

**This has already happened once.** `home/CLAUDE.md` sat 7h ahead of the
deployed copy after PRs #3 and #7: the live rules were missing the entire
context-instruments section and still named private-marketplace skills that
`EXCLUDED.md` had stripped. Nothing surfaced it, because a stale rules file
loads, parses, and reads as authoritative exactly like a current one.

## The idea the whole repo encodes

**A zero denominator is an abstention, not a pass.** Every artifact here is a
variation on it, and changes that quietly weaken it are the main regression risk:

- `run-all.sh` treats zero matched suites as a hard **failure** — a runner that
  globs, matches nothing, and exits 0 is the exact false green the hooks watch for.
- `tooling-rot-siren.sh` is silent with **no** watchlist (nothing was asked for)
  but reports loudly on an **empty** one (coverage was intended and is absent),
  and flags a watched `cli` with no `npm` key as *partial coverage*. Silence is
  earned by declaring a gap (`"npm_exempt": true`), never by omitting a key.
- A blank statusline, an unfired nudge, and a hook killed by timeout all look
  identical to "all clear" — which is why each hook has an explicit degraded
  output rather than a quiet path.
- `check-drift.sh` spends a whole third exit code on "nothing was installed
  here", counts deployed **files** rather than directories (an empty
  `~/.claude/hooks/` is not an install), and prints its comparison count even on
  a clean run.

When editing a hook, ask what its *silent* state is indistinguishable from.

## Load-bearing invariants (each one is a shipped bug)

These are pinned by tests; breaking them is how the escaped defects escaped.

| Invariant | Where | Why |
|---|---|---|
| Watchlist fields joined with `\x1f`, never tab | `tooling-rot-siren.sh:110,141` | Tab is IFS whitespace, so `read` collapses empty fields and every value shifts left — findings then name the wrong CLI |
| The watch loop reads on **FD 3** (`read -u 3`) | `tooling-rot-siren.sh:141` | A subprocess in the loop body (an MCP stdio server that ignores `--version`) will otherwise eat the watchlist off stdin and silently drop entries |
| The hot path makes **no** network call | `tooling-rot-siren.sh` | A blocking `npm view` hits the 10s hook timeout and is killed mid-run, printing nothing. npm drift reads a cache refreshed by a detached re-invocation (`--refresh-npm-cache`); cache writes are atomic |
| Nudge requires **evidence, not intent** | `clear-nudge.sh` | Keying on the command string announced commits that never happened — a grep, an echo, a doc example and a test fixture all contain `git commit`. It also discards the call if any part errored, because `a; b; c` reports one exit status |
| Statusline uses the **last** usage record, not a sum | `statusline-context.sh` | Sidechain (subagent) turns spend real tokens but were never in the main window: they count toward `burn`, never toward the gauge |
| Hooks derive every path from `$HOME` | all three | Suites run each case against a synthetic `$HOME`; a hardcoded path makes the test touch the real `~/.claude` |
| The `@import` check canonicalizes the **target**, not the line | `check-drift.sh` | Skipping line 6 wholesale would pass an import rewritten to point elsewhere — the one edit that unloads every shared rule while the file still looks correct |
| The drift check never writes | `check-drift.sh` | Auto-repair would destroy the evidence of how far behind the machine had drifted, which is the actual finding |

## Conventions specific to this repo

- **`home/CLAUDE.md` is not this file.** It is the artifact deployed to
  `~/.claude/CLAUDE.md` on the target machine — Claude-only mechanics, opening
  with an `@import` of `home/ai-rules/global.md`. The split is by *audience*:
  anything naming a skill, hook, or `settings.json` key belongs in
  `home/CLAUDE.md`; everything else in `home/ai-rules/global.md`, which four
  agents read. On an installed machine the shared file is typically symlinked
  into Gemini/Codex/Copilot, so a careless write to `~/.claude/CLAUDE.md` can
  clobber the rules for all of them. And because nested `CLAUDE.md` files are
  picked up from directories being worked in, `home/CLAUDE.md` may load as
  *instructions* while you edit the bundle. It is cargo, not guidance — its
  "prefer skill X", "never heredoc" rules describe a target machine. Read it as
  text to be edited, not obeyed.
- **Comment the *why*, at length.** Every hook and suite opens with a header
  explaining the incident that produced it. A rule without its reason gets
  dropped the first time it is inconvenient — that is deliberate house style
  here, not verbosity to trim.
- **Themed test output is intentional** (`▲ every suite flew clean`). Keep it.
- **Nothing employer-, client-, or private-marketplace-specific ships.**
  `EXCLUDED.md` records what was left behind and why; add to it rather than
  re-litigating a cut.
- **Never commit an allowlist.** `.claude/settings.local.json` is gitignored and
  `settings.template.json` ships `permissions.allow: []` on purpose — this repo
  moves setups between laptops, which is precisely the leak vector.
- **`enabledPlugins: false` entries are kept on purpose** — they record which
  plugins were evaluated and switched off, so the decision survives the next
  machine. Don't prune them.

## Testing changes to a hook

Repo tests exercise `home/hooks/*.sh` directly. They cannot catch install-time
problems — wrong path, missing exec bit, a stale deployed copy — so after
changing a hook, also run the three manual probes in `INSTALL.md` §3 against
`~/.claude/hooks/`. Probe 2 (the parsing path) is the one that matters: probe 1
alone has a zero denominator, since it only ever exercises the
nothing-to-check branch.
