# Roadmap and strategy for `claude-portable-setup`

**Status:** proposed — awaiting sign-off
**Skill:** harness-brainstorming
**Date:** 2026-08-22
**Keywords:** portable-setup, core-overlay, deploy-drift, false-green, windows-portability, harness-adoption, ci-matrix, zero-denominator, reference-implementation

> **Supersedes** `docs/superpowers/specs/2026-08-20-roadmap-strategy-design.md`
> (committed at `374b1d6`). That document is retained deliberately: it records how
> these decisions were reached. This proposal is the canonical, harness-shaped
> version and is the one downstream skills should read.

---

## Authoring conditions (disclosure)

**[UNVERIFIED]** This spec was authored without `gather_context` grounding. The
harness MCP server was connected but non-functional throughout — two
`harness-mcp` processes started `Thu Aug 20 16:13`, 72 seconds before
`@harness-engineering/cli@11.3.0` replaced the content-hashed chunks beneath
them, and neither respawned across two reconnect attempts (uptime 1d 07h at
time of writing). All `mcp__harness__*` calls fail on module resolution while
`/mcp` correctly reports the server as connected.

The grounding actually lost is small and is stated rather than assumed:

| Source | Status |
|---|---|
| `docs/knowledge/` (businessKnowledge) | Does not exist in this repo — nothing to lose |
| `.harness/graph` | Exists but predates every decision in this document |
| `STRATEGY.md` (step 0a) | Absent — `read_strategy` would soft-fail regardless |
| Codebase, git history, npm registry | Read directly and cited below |

Claims about the codebase in this document are cited to `file:line`. The
condition itself becomes roadmap item **M4-3**, because it is a new
silent-degradation shape the existing siren structurally cannot catch.

---

## Overview and goals

### The problem

The repo has twelve merged PRs, four regression suites, 99 test cases, and no
statement of what it is for. Every artifact was justified against a local
argument and none against a whole. That held while there was one consumer. It
stopped holding when three constraints arrived together:

1. The audience is **strangers**, not only the author.
2. A targeted consumer is on **Windows**, which nine `#!/bin/bash` artifacts do
   not serve (`home/hooks/*.sh`, `tools/check-drift.sh`, `tests/*.sh`).
3. The author needs a **company overlay**, which `EXCLUDED.md` forbids by
   construction today.

Each is individually answerable. Together they imply an architecture, and this
spec records it before any of it is built.

### Goals

- State what the repo is, who it serves, and what it refuses to do.
- Restructure it as a **public core with layered overlays**, so one bundle
  serves a stranger, its author, and a company without a fork.
- Make its own gates un-skippable, on every OS it claims to support.
- Adopt harness and canary at the depth the public-core constraint permits.

### Non-goals

- Not an application. No build step, no package manager, no runtime of its own.
- No private-marketplace artifact in the core.
- Never commit an allowlist (`settings.template.json` ships
  `permissions.allow: []` on purpose).
- No auto-repair anywhere — the size of a gap is the finding.
- Not a published plugin **yet**; M4 earns that decision rather than assuming it.
- No new hooks or skills until M1–M3 land.

---

## Decisions made

Seven decisions, each chosen from 2–4 options with tradeoffs presented. D1–D6
were decided during brainstorming; D7 was forced by a contradiction the tooling
surfaced while validating this spec.

### D1 — Identity: public reference implementation

**Chosen over:** personal carry-over · both · idea incubator.
**Why:** it sets the success test as *"a stranger clones it and it works on their
machine."* Every later decision inherits that test.
**Consequence:** where a convenience helps only the author but assumes something
about their machine, the stranger wins and the author's version moves to an
overlay.

### D2 — Rules voice: split principle from profile

**Chosen over:** rewrite to second person · leave first-person.
**Evidence:** `home/ai-rules/global.md` carries 14 first-person references
outside blockquotes; `home/CLAUDE.md` carries zero. The two shipped files already
disagree about who is speaking, and the divergence is invisible to every gate.
**Why:** rule 1 — the single most adoptable idea in the repo — currently opens
`## 1. Visual first — I am a visual learner`, attaching the most valuable rule to
a stranger's personal fact.
**Consequence:** `global.md` states principles; `profile.example.md` carries the
calibration (visual learner, machine count, visual level).

### D3 — CI must prove three things

**Chosen over:** matrix only · ubuntu only.
**Why:** the repo's thesis is that a gate nobody ran is not a pass, yet its own
four gates run only when a human remembers. A single-runner green tick would be a
partial denominator wearing a full-coverage badge.
**Consequence:** OS matrix, plus a bare-`$HOME` install job asserting
`check-drift.sh` exits **0, not 2** — proving the install *happened* rather than
that nothing differed because nothing was there (`tools/check-drift.sh` reserves
exit 2 for that abstention).

### D4 — Deliverable shape: STRATEGY.md + ROADMAP.md + tracked issues

**Chosen over:** two docs only · one merged file.
**Why:** *"M1 done ✓"* written in a markdown file is a status claim with no
backing commit. Issues make progress reachable from a commit.
**Consequence:** strategy stays durable; roadmap churns; they live in separate
files because they change at different rates.

### D5 — Windows: port hooks to pure Python

**Chosen over:** require WSL/Git Bash · ship PowerShell twins.
**Evidence:** the hooks are already mostly Python — `clear-nudge.sh` 88%,
`statusline-context.sh` 82%, `tooling-rot-siren.sh` 60%; bash is a shim around
embedded `python3` heredocs. `tools/check-drift.sh` is 0% Python (183 lines) and
is the one genuine rewrite.
**Why:** one implementation across three OSes beats two implementations that
drift, and beats a prerequisite (WSL) that may silently not be met. Native
Claude Code on Windows may not route a `#!/bin/bash` hook at all — and a hook
that fails to execute produces **no output**, which is indistinguishable from a
hook that ran clean.
**Consequence:** the exec-bit invariant has no meaning on NTFS and must declare a
skip rather than silently pass.

### D6 — Adoption depth: public CLIs in core, private plugins in the overlay

**Chosen over:** full adoption incl. private deps · harness now / canary later.

This decision resolves a conflict with existing repo policy, so it is recorded in
full rather than summarised.

`EXCLUDED.md:14-15` excludes harness and canary as private-marketplace tooling,
and `.gitignore` excludes `.harness/` citing the same reason. `CLAUDE.md`
instructs that cuts be *added to* rather than re-litigated. Adopting both
appeared to contradict all three.

The conflict was factual, not editorial. Checked against the npm registry:

| | Package | Resolves without auth? | Plugin layer |
|---|---|---|---|
| harness | `@harness-engineering/cli@11.3.0` | **Yes** | private, ~50 commands + 15 agents, SSO-gated |
| canary | `canary-test-cli@7.0.0` | **Yes** | `canary@bop-clocktower`, private |

`EXCLUDED.md:15` therefore over-claims: correct about the plugin, wrong about the
CLI, which was public the whole time. This is the same shape the repo already
documents about its own retired `npm_exempt` entry — *"uninvestigated coverage
debt wearing a declared-gap label"* (`home/hooks/rot-watch.json` comment).

**Consequence:** public CLIs become committed dev tooling; the private plugin
layer becomes the first tenant of the company overlay. Rows 14–15 are **split**,
not deleted; every other row in `EXCLUDED.md` is preserved verbatim.

### D7 — Parity is proven by a repo-local runner, not by `canary-shadow`

**Chosen over:** making SC-5 maintainer-tier · keeping the private dependency and
documenting the gap.

**How this surfaced:** `harness advise-skills` returned 0 matches across 783
indexed skills. The null result was correct and informative rather than noise —
the harness skill index contains **zero** canary entries, because `canary-shadow`
ships only from the private marketplace
(`~/.claude/plugins/marketplaces/bop-clocktower/agents/skills/claude-code/canary-shadow`),
and the public `canary-test-cli@7.0.0` exposes no `shadow` subcommand.

**The contradiction it exposed:** D6 establishes that the core installs with no
private dependency. The original SC-5 made the safety net for M2's ~1,185-line
rewrite depend on a private-marketplace skill. Both were defensible alone;
together they meant a stranger could not run the criterion that makes the repo's
largest change safe — the public-core invariant broken by the criterion meant to
protect it.

**Why a repo-local runner:** the check must run where the claim is made. Under a
maintainer-tier SC-5 the strongest evidence would exist only on the author's
laptop, which is the "runs green in my session" pattern the repo's own rules
reject as a status claim. The runner drives the **existing** fixtures through
both implementations, normalizes, and diffs — the same idea as `canary-shadow`,
scoped to what this repo needs.

**Consequence:** `canary-shadow` remains available to the author as an
overlay-tier check that adds capability on top of a core that stands alone. The
overlay is permitted to be richer than the core; it is not permitted to be
load-bearing for it.

---

## Technical design

### Core plus overlays

```
  ┌─ CORE (public, this repo, CI-proven on 3 OSes) ────────────┐
  │  ai-rules/global.md    neutral principles, each with why   │
  │  hooks/                siren · statusline · nudge          │
  │  skills/               visual-decisions                    │
  │  settings.template     no allowlist, no private plugins    │
  │  harness.config.json   public CLI config, committed        │
  └────────────────────────┬───────────────────────────────────┘
                           │  precedence: machine > company > profile > core
     ┌─────────────────────┼─────────────────────┬─────────────────────┐
     ▼                     ▼                     ▼                     ▼
  PROFILE              COMPANY               MACHINE              (absent)
  profile.md           company/               rot-watch.json       core alone
  visual learner       private marketplace    permissions.local    is valid and
  machine count        client conventions     node/mise paths      complete
  visual level         .canary/company.json   exec-bit facts       ← the stranger
```

### Layer contracts

- **Core** — knows nothing about any overlay; must be fully functional with every
  overlay absent. This is precisely what D3's bare-`$HOME` job proves.
- **Profile** — per-person calibration. Facts about a human, not rules.
- **Company** — per-org extension. Gitignored here, or a sibling private repo.
  `EXCLUDED.md` becomes its specification.
- **Machine** — per-machine facts that must never be inherited: the rot
  watchlist, the permission allowlist, absolute toolchain paths.

Precedence is `machine > company > profile > core`. Nothing in a lower layer may
depend on a higher layer existing.

### Why overlays rather than a private fork

A private fork of a public repo diverges silently, and this repo's own history is
the argument: `home/CLAUDE.md` sat seven hours ahead of its deployed copy after
PRs #3 and #7 and nothing surfaced it, because a stale file loads and parses
exactly like a current one (`CLAUDE.md`, "This has already happened once"). A
fork is that failure with a longer fuse. An overlay cannot drift from the core
because it never contains a copy of it.

### Invariants

Each already has a shipped bug behind it, which is why these are invariants
rather than preferences.

| Invariant | Now extended to |
|---|---|
| A zero denominator is an abstention, not a pass | CI itself: a skipped matrix leg is not a green tick |
| Silence is earned by declaring a gap, never by omitting a key | The Windows exec-bit check must declare its skip |
| The core installs with no private dependency | `npm i -g` twice; no marketplace, no SSO |
| Overlays layer, never fork | Core stays unaware of overlays |
| A check reports, never repairs | All future checks, including reverse drift |
| Every artifact states the incident that produced it | Python ports carry comments over verbatim |

---

## Integration Points

### Entry Points

- **New CI entry point:** `.github/workflows/*.yml` — the repo has no CI today.
- **New repo-local tools:** `tools/parity-check` (M2) and the reverse-drift
  check (M4), both under `tools/` alongside `check-drift`.
- **Changed install entry point:** `INSTALL.md` gains an overlay step; its step
  count and §7 re-install flow both change.
- **Changed hook entry points:** the three `settings.template.json` hook
  commands change interpreter when the hooks become Python (`statusLine`,
  `SessionStart`, `PostToolUse` — currently `$HOME/.claude/hooks/*.sh`).
- **New harness entry point:** `harness.config.json` at repo root.

### Registrations Required

- `settings.template.json` hook/statusline command paths re-pointed after the
  Python port, per-OS if the interpreter name differs (`python3` vs `py`).
- `tools/check-drift.sh` file list updated for renamed artifacts, plus a third
  overlay target.
- `.gitignore`: `.harness/` un-ignored (D6); overlay paths added.
- Branch protection on `main` requiring the new CI jobs — without it the
  workflow exists but does not gate, which is a green tick nobody enforced.

### Documentation Updates

- `README.md` — the "What's in it" table lists every shipped artifact by
  filename; the Python port invalidates all of it.
- `CLAUDE.md` — the four-gate block, the commands block, and the
  "Load-bearing invariants" table all name `.sh` files and bash-specific
  reasoning.
- `INSTALL.md` — overlay step, Windows path, revised step counts.
- `EXCLUDED.md` — re-scoped from cut list to overlay spec; rows 14–15 split.
- `home/ai-rules/global.md` + new `profile.example.md` (D2).
- **New:** `STRATEGY.md`, `ROADMAP.md` at repo root.

### Architectural Decisions

Two decisions rise to standalone ADRs:

- **D6 — public CLI in core, private plugin in overlay.** It reverses a recorded
  exclusion that repo policy protects from re-litigation, so the reasoning must
  outlive this spec or the next reader restores the old rule.
- **D5 — bash to Python.** It changes the implementation language of every
  shipped artifact and retires the exec-bit invariant on one OS. A future reader
  finding a Python hook needs the reason without archaeology.

D1–D4 do not warrant separate ADRs; they are captured above.

### Knowledge Impact

Concepts that should enter the knowledge graph:

- **Core/overlay layering** with its precedence rule — the organising concept.
- **Abstention as a distinct outcome** — exit 2 in `check-drift.sh`, the empty
  vs. absent watchlist distinction in the siren, and now a skipped CI leg.
- **Connected ≠ functional** — the MCP failure documented above: a liveness
  surface reporting green over a non-functional process.
- **Declared-gap discipline** — `npm_exempt`, and now the NTFS exec-bit skip.
- **The overlay may be richer than the core, never load-bearing for it** — D7's
  generalisable rule for every future overlay-tier capability.

---

## Success criteria

Observable and testable. Each is checkable by something other than judgment.

1. **SC-1** — `STRATEGY.md` and `ROADMAP.md` exist at repo root and parse under
   `harness validate`.
2. **SC-2** — When a PR is opened, CI shall run the four gates on
   `ubuntu-latest`, `macos-latest`, and `windows-latest`, and `main` shall refuse
   a merge if any leg did not run.
3. **SC-3** — The bare-install job shall exit 0 from
   `CHECK_ROOT=$TMP ./tools/check-drift.sh` (M1) / `./tools/check_drift.py` (M2
   onward) after carrying out `INSTALL.md`; an exit of 2 shall fail the job. The
   job invokes whichever artifact currently exists, so the criterion survives the
   M2 rename rather than silently going unrun across it.
4. **SC-4** — The bare-install job shall print, on both pass and fail paths, the
   `INSTALL.md` targets it did not verify (§5 `settings.json`, §6 memory seeds).
5. **SC-5** — `./tools/parity-check` shall report zero unexplained divergence
   between the bash baseline and the Python candidate for every ported artifact,
   and shall run in CI on all three OSes with no private dependency. It shall
   fail when zero artifacts were compared — an empty comparison is an abstention,
   not parity.
6. **SC-6** — On Windows, the exec-bit check shall emit an explicit declared skip;
   if it emits nothing, the job shall fail.
7. **SC-7** — `grep -vE '^\s*>' home/ai-rules/global.md | grep -cE '\bI\b|\bmy\b'`
   shall return `0` (baseline today: 14).
8. **SC-8** — The bare-install job shall pass with every overlay absent.
9. **SC-9** — `EXCLUDED.md` shall contain a separate row for each of the public
   CLI and the private plugin layer, and every other row shall be byte-identical
   to its current content.
10. **SC-10** — Reverse drift shall report on both pass and fail paths, and shall
    exit non-zero when `$HOME` holds a change absent from `home/`.

---

## Implementation order

### M1 — Prove the green

Rationale for ordering: M2 rewrites ~1,185 lines of tested shell. Doing that
above a human-remembered gate changes the safety net and the thing it protects in
the same window.

- CI workflow: matrix `[ubuntu-latest, macos-latest]`, four gates.
- `bare-install` job (SC-3, SC-4).
- `harness init`; commit `harness.config.json`; un-ignore `.harness/`.
- `STRATEGY.md`, `ROADMAP.md` land (SC-1).
- One tracked issue per remaining roadmap item, linked both ways.

**Exit:** SC-1, SC-2 (two OSes), SC-3, SC-4.

### M2 — One core, three OSes

- Port the three hooks and `check-drift` to pure Python; carry every "why"
  comment over verbatim.
- **Build `tools/parity-check` first**, against the bash baseline while it is
  still the only implementation. Parity is then proven by it (SC-5) — **not** by
  the rewritten suites alone, since those move with the implementation.
- `windows-latest` joins the matrix (SC-2).
- Exec-bit check declares its NTFS skip (SC-6).
- **Open question for implementation:** whether Claude Code on native Windows
  resolves `python3` or `py`. Verify on a real runner; do not assume.

**Exit:** SC-2 (three OSes), SC-5, SC-6.

### M3 — Core plus overlay

Disjoint from M2 (documents versus code), so it may run concurrently in a
separate worktree per the repo's concurrency convention.

- `global.md` rewritten to neutral voice with incidents blockquoted (SC-7).
- `profile.example.md` introduced.
- `EXCLUDED.md` re-scoped; rows 14–15 split (SC-9).
- Company overlay contract documented; `INSTALL.md` overlay step; drift check
  gains its third target.

**Exit:** SC-7, SC-8, SC-9.

### M4 — Keep it honest

- **M4-1** Reverse drift: `home/` ← `$HOME` (SC-10). The existing check catches a
  bundle change never deployed; nothing catches a live fix never captured, and
  that direction loses work permanently.
- **M4-2** Versioned releases, so an adopter can name their version.
- **M4-3** **Orphaned-process detection.** A tool upgrade can leave a long-lived
  child process running against replaced files while every liveness surface
  reports green. The siren cannot catch this by construction: it compares
  versions, and here the version drift was *resolved* at the moment the tooling
  broke. Scope to be determined during M4 — detection may belong in the siren, a
  new hook, or documentation only.
- **M4-4** Adoption document.
- **M4-5** Decide, with evidence from real adoption, whether the siren graduates
  into a standalone plugin. Not assumed.

**Exit:** SC-10, plus a tagged release.

---

## Risks

| Risk | Why plausible here | Mitigation |
|---|---|---|
| The Python port silently changes behavior | The tests are rewritten in the same change | `tools/parity-check` differential parity against the bash baseline (SC-5), built before the port begins |
| `parity-check` compares nothing and reports green | An empty artifact list is the classic zero denominator | SC-5 requires it to fail when zero artifacts were compared |
| Windows hook invocation wrong in a way CI misses | CI runs scripts directly; Claude Code invokes them differently | Manual `INSTALL.md` §3 probes on a real Windows machine before M2 closes |
| Overlay model built for a tenant that doesn't exist | Speculative generality | M3 builds only what the author's actual overlay needs; the contract is documented, not implemented for hypothetical tenants |
| `EXCLUDED.md` rewrite re-litigates settled cuts | `CLAUDE.md` forbids it | Only rows 14–15 change, only because they were factually wrong; SC-9 pins the rest byte-identical |
| Adopting harness/canary adds a dependency a stranger cannot satisfy | The original exclusion assumed exactly this | Both CLIs verified public on npm; plugin layer stays overlay-only; SC-8 proves the core installs without them |
| CI exists but does not gate | A workflow without branch protection is decorative | Branch protection listed as a required registration |
