# Roadmap and strategy for `claude-portable-setup`

**Date:** 2026-08-20
**Status:** approved design, not yet implemented
**Supersedes:** nothing — this is the repo's first strategy artifact

---

## Why this document exists

The repo has twelve commits, twelve merged PRs, four regression suites, and zero
statements of what it is for. Every artifact in it was justified against a local
argument — this hook catches that bug, this check reports that gap — and none
against a whole. That worked while the repo was one person's carry-over. It stops
working the moment a second consumer exists, because "should we add X" has no
answer without a statement of what X would be serving.

Three constraints arrived during the design conversation that the existing repo
could not have absorbed without one:

1. The audience is **strangers**, not only the author.
2. One targeted consumer is on **Windows**, which the bash artifacts do not serve.
3. The author needs a **company overlay**, which `EXCLUDED.md` currently forbids
   by construction.

Each of those is individually answerable. Together they imply an architecture,
and this document records it before any of it is built.

---

## 1. Strategy

### 1.1 What this is

A **public reference implementation of an agent working setup**, structured as a
public core with layered overlays, so that one bundle serves a stranger, its
author, and a company without any of them forking it.

### 1.2 Who it serves, in priority order

| # | Consumer | What success looks like for them |
|---|---|---|
| 1 | A Claude Code user on macOS, Linux, or Windows | Clones it, runs the install, and the hooks work on their OS without them editing anything |
| 2 | The author, across machines | A new machine reaches parity in one pass; no live fix is ever silently lost |
| 3 | A company | Layers private tooling on top via a documented extension point, never a fork |

Priority order is load-bearing. Where consumer 1 and consumer 2 conflict — a
convenience that only helps the author but assumes something about their machine
— consumer 1 wins, and the author's version moves to an overlay.

### 1.3 Invariants

These may not be weakened by any change. Each already has a shipped bug behind
it, which is why they are stated as invariants rather than preferences.

| Invariant | Origin | Now extended to |
|---|---|---|
| A zero denominator is an abstention, not a pass | A test toolchain reported green for ~7 weeks while broken | CI itself: a matrix leg that was skipped is not a green tick |
| Silence is earned by declaring a gap, never by omitting a key | The `npm_exempt` entry justified by a wrong package name | The Windows exec-bit check must **declare** its skip, not merely not-run |
| The core installs with no private dependency | New | `npm i -g` twice; no marketplace, no SSO, no auth wall |
| Overlays layer, never fork | New | Precedence `machine > company > profile > core`; core stays unaware of overlays |
| A check reports, never repairs | `check-drift.sh` by contract | All future checks, including reverse drift |
| Every artifact states the incident that produced it | House style since the first commit | Applies to Python ports too — comments carry over, they are not refactoring debris |

### 1.4 Non-goals

Explicit refusals. This section exists so that roadmap drift has something to be
measured against; an idea that contradicts a line here is rejected without
re-argument, or this section is amended first.

- **Not an application.** No build step, no package manager, no runtime of its own.
- **No private-marketplace artifact in the core.** Those live in the company
  overlay. `EXCLUDED.md` is re-scoped from a graveyard of permanent cuts into the
  overlay's specification.
- **Never commit an allowlist.** `settings.template.json` ships
  `permissions.allow: []` on purpose; this repo moves setups between machines,
  which is precisely the leak vector.
- **No auto-repair anywhere.** The size of a gap is the finding; repairing it
  destroys the evidence.
- **Not a published plugin — yet.** M4 earns the right to make that decision; it
  is not assumed here.
- **No new hooks or skills** until M1–M3 land. Growth of the artifact count is
  not growth of the thing.

### 1.5 The conflict this design resolves

`EXCLUDED.md:14-15` records harness and canary as private-marketplace tooling
excluded from a public bundle, and `.gitignore` excludes `.harness/` for the same
stated reason. `CLAUDE.md` instructs that cuts be added to rather than
re-litigated. That conflicted with the decision to adopt both.

The conflict was factual, not editorial. Checked against the registry:

| | npm package | Public? | Plugin / marketplace |
|---|---|---|---|
| harness | `@harness-engineering/cli@11.3.0` | **Yes**, no auth | private, ~50 commands + 15 agents, SSO-gated |
| canary | `canary-test-cli@7.0.0` | **Yes**, no auth | `canary@bop-clocktower`, private |

Both CLIs resolve from npm without authentication. `EXCLUDED.md:15` therefore
over-claims: it is correct about the plugin and wrong about the CLI, which was
public the whole time. This is the same failure mode the watchlist comment
already documents about the old `npm_exempt` entry — *"uninvestigated coverage
debt wearing a declared-gap label."*

**Resolution:** the public CLIs become committed dev tooling; the private plugin
layer becomes the first tenant of the company overlay. `EXCLUDED.md:14-15` is
rewritten to split the two claims rather than deleted.

---

## 2. Architecture: core plus overlays

```
  ┌─ CORE (public, this repo, CI-proven on 3 OSes) ────────────┐
  │  ai-rules/global.md    neutral principles, each with why   │
  │  hooks/                siren · statusline · nudge          │
  │  skills/               visual-decisions                    │
  │  settings.template     no allowlist, no private plugins    │
  │  harness.config.json   public CLI config, committed        │
  └────────────────────────┬───────────────────────────────────┘
                           │  layered at install time
                           │  precedence: machine > company > profile > core
     ┌─────────────────────┼─────────────────────┬─────────────────────┐
     ▼                     ▼                     ▼                     ▼
  PROFILE              COMPANY               MACHINE              (absent)
  profile.md           company/               rot-watch.json       core alone
  "visual learner"     private marketplace    permissions.local    is valid and
  machine count        client conventions     node/mise paths      complete
  visual level         internal registries    exec-bit facts       ← the stranger
  ▲ per-person         ▲ per-org, gitignored  ▲ per-machine
                         or a sibling private
                         repo cloned beside
```

### 2.1 Layer contracts

Each layer is independently understandable and independently absent.

- **Core** — knows nothing about any overlay. Must be fully functional with every
  overlay missing. This is the property CI's bare-`$HOME` install job proves.
- **Profile** — per-person calibration. Facts about a human, not rules: whether
  they are a visual learner, how many machines they run, what visual level they
  default to. Shipped as `profile.example.md`; the real one is the adopter's.
- **Company** — per-org extension. Private marketplaces, internal registries,
  client conventions, `.canary/company.json`. Gitignored here, or a sibling
  private repo. `EXCLUDED.md` becomes its spec.
- **Machine** — per-machine facts that must never be inherited: the rot watchlist,
  the permission allowlist, absolute toolchain paths.

**Precedence is `machine > company > profile > core`.** A more specific layer
overrides a less specific one. Nothing in a lower layer may depend on a higher
one existing.

### 2.2 Why the overlay model rather than a fork

A private fork of a public repo diverges silently, and this repo's own history is
the argument: `home/CLAUDE.md` sat seven hours ahead of its deployed copy after
PRs #3 and #7, and nothing surfaced it, because a stale file loads and parses
exactly like a current one. A fork is that failure mode with a longer fuse. An
overlay cannot drift from the core because it never contains a copy of it.

---

## 3. Roadmap

Four milestones, ordered by dependency rather than by appetite. Each has a
done-condition that is checkable by something other than a person's judgment,
per the rule that a status claim must be reachable from a commit.

### M1 — Prove the green

**Why first:** M2 is a rewrite of roughly 1,185 lines of tested shell. Doing that
on top of a human-remembered gate would mean the safety net and the thing it
protects both change in the same window. CI has to exist before the rewrite, not
after it.

- GitHub Actions workflow, matrix `[ubuntu-latest, macos-latest]`, running the
  four gates: `bash -n`, `shellcheck` (hooks at default severity, suites at
  `-S warning`), both JSON parses, `./tests/run-all.sh`.
- A `bare-install` job: `HOME=$(mktemp -d)`, carry out `INSTALL.md`, then
  `CHECK_ROOT=$HOME ./tools/check-drift.sh` **asserting exit 0, not exit 2**.
  The exit-2 assertion is the point — it proves the install happened, rather than
  proving that nothing differed because nothing was there.
- `harness init`; commit `harness.config.json`; un-ignore `.harness/`.
- `STRATEGY.md` and `ROADMAP.md` land, in harness's expected shape so its
  `validate_strategy` and roadmap tooling read them natively.
- One GitHub issue per remaining roadmap item, linked both ways.

**Done when:** a PR cannot merge without both jobs green on both OSes, and
`harness validate` passes against the committed config.

**Known gap this milestone does not close:** `INSTALL.md` §5 (`settings.json`)
and §6 (memory seeds) remain outside the drift check for the reasons
`CLAUDE.md` already documents. The bare-install job must therefore print what it
did *not* verify, on both the pass and fail paths, matching the existing
disclosure contract.

### M2 — One core, three OSes

**Why second:** it unblocks the Windows consumer, and it is the largest and
riskiest change, so it goes immediately after the gate that protects it.

- Port `tooling-rot-siren.sh`, `statusline-context.sh`, `clear-nudge.sh`, and
  `tools/check-drift.sh` to pure Python. The three hooks are already 60–88%
  embedded Python; the bash is a shim being deleted rather than translated.
  `check-drift.sh` (183 lines, 0% Python) is the one genuine rewrite.
- **Parity is proven by `canary-shadow`**, not by the rewritten suites alone.
  Same inputs through the bash baseline and the Python candidate, normalized,
  diffed. Rewriting the tests alongside the implementation means the net and the
  thing it catches move together; the differential run is the only check that
  does not.
- `windows-latest` joins the CI matrix.
- The exec-bit invariant has no meaning on NTFS. It must **declare a skip with a
  stated reason**, never silently pass — the repo's own rule that silence is
  earned by declaring the gap, applied to itself.
- Every "why" comment carries over verbatim. They are the artifact, not
  scaffolding.

**Done when:** all three OSes green; `canary-shadow` reports zero unexplained
divergence between baseline and candidate; the Windows run shows the exec-bit
check as an explicit declared skip.

**Open question deferred to implementation:** whether Claude Code on native
Windows resolves `python3` or `py`. The settings template's hook invocation must
be verified on a real Windows runner, not assumed.

### M3 — Core plus overlay

Disjoint from M2 (documents and rules, versus hooks and tools), so it may run
concurrently in a separate worktree per the repo's concurrency convention.

- `home/ai-rules/global.md` rewritten to neutral voice: each rule states the
  principle and, beneath it, the incident that produced it. The 19 first-person
  references move out.
- `home/ai-rules/profile.example.md` introduced — visual level, machine count,
  the visual-learner fact.
- `EXCLUDED.md` rewritten from a cut list into the company-overlay spec; rows
  14–15 split so the public CLI and the private plugin stop sharing one claim.
- The company overlay contract documented: what it may contain, how it layers,
  what it may not assume.
- `INSTALL.md` gains an overlay step and the drift check gains its third target.

**Done when:** first-person voice survives only inside blockquoted incident text,
checked mechanically as

```bash
grep -vE '^\s*>' home/ai-rules/global.md | grep -cE '\bI\b|\bmy\b'   # must be 0
```

(baseline today: 14 across the whole file) — and `profile.example.md` installs
cleanly, and the bare-install job still passes with every overlay absent.

Blockquoting the incidents is what makes this checkable at all. The first draft
of this done-condition said "0 outside quoted incident text" while proposing a
command that counts quoted text too — a done-condition that could never return 0,
in a spec whose subject is rejecting exactly that.

### M4 — Keep it honest

- **Reverse drift**: `home/` ← `$HOME`. The existing check catches a bundle change
  that was never deployed. Nothing catches a live fix that was never captured,
  which is the direction that loses work permanently.
- Versioned releases, so an adopter can say which version they are on.
- An adoption document: what to take, what to leave, what assumes what.
- Decide — with evidence from real adoption — whether the siren graduates into a
  standalone plugin. Not assumed here.

**Done when:** reverse drift is tested and reported on both paths, and a tagged
release exists that a stranger can name.

---

## 4. Explicitly out of scope

Named so that later sessions do not quietly absorb them:

- Extracting any artifact into a standalone plugin before M4 decides it.
- Any new hook or skill before M1–M3 land.
- Writing to the live `~/.claude` beyond the existing read-only drift check.
- Migrating the test suites to a framework beyond what M2's parity work requires.

---

## 5. Risks

| Risk | Why it is plausible here | Mitigation |
|---|---|---|
| The Python port silently changes hook behavior | The tests are rewritten in the same change | `canary-shadow` differential parity against the bash baseline |
| The Windows hook invocation is wrong in a way CI does not model | CI runs the scripts; Claude Code invokes them differently | Manual probes from `INSTALL.md` §3 on a real Windows machine before M2 closes |
| The overlay model is designed for a company overlay that does not exist yet | Speculative generality | M3 builds only what the author's actual overlay needs; the contract is documented, not implemented for hypothetical tenants |
| `EXCLUDED.md`'s rewrite re-litigates settled cuts | `CLAUDE.md` forbids that | Only rows 14–15 change, and only because they were factually wrong; every other row is preserved verbatim |
| Adopting harness/canary adds a dependency a stranger cannot satisfy | The original exclusion assumed exactly this | Both CLIs verified public on npm; the private plugin layer stays overlay-only, and CI's bare-install job proves the core installs without them |
