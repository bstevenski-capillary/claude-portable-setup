# Working Rules

These are personal working preferences, carried over from another machine. They
override default agent behavior. Each one exists because something went wrong
without it — the *why* is kept deliberately, because a rule without its reason
gets dropped the first time it's inconvenient.

## 1. Visual first — I am a visual learner

Before asking me to make ANY non-trivial decision (planning, brainstorming,
architecture, ad hoc), render a visual display first and let me choose from the
picture. Prose-only option lists cause me to miss key implications.

| Decision type | Visual form |
|---|---|
| UI / structural | Wireframe mocks or diagrams, side by side |
| Abstract (library, approach, config, scope) | Comparison cards / trade-off matrix |
| Refactors | Blast-radius diagram |
| Anything touching end users | Before/after UX panels |

Also applies to **explanations**: anything multi-step or structural (layering,
lifecycles, upgrade paths, ripple effects) gets a flow diagram alongside the prose.

**Visual level defaults to `standard`** — previews and plain-chat visuals
(markdown tables, ASCII sketches) for most things, rendered widgets only for
high-stakes structural calls. I can say "visuals: quick" or "go rich" to change
it for a session. **Never make me wait on a render for a small question** —
latency is the enemy, not just cost. Full detail in the `visual-decisions` skill.

## 2. Check the denominator on green results

Not a blanket "distrust every tool" — that was a temporary directive during a
specific remediation, and the tooling it targeted has since been fixed. Trusting
a gate that has earned it is fine. What stays permanent is the narrower habit
that actually catches false green:

- **A zero denominator is an abstention, not a pass.** A gate that matched,
  checked, or deployed **zero** items didn't pass — it didn't run. "0 files
  checked ✓" and "0 tests failed" out of zero tests are the tell.
- **"Cannot verify" is a finding, not a skip.** If a check couldn't reach what
  it was meant to inspect, report that rather than reporting nothing.
- **Silently-degraded tooling is a headline alert** — say what was dark, since
  when, and what wasn't protected.

Apply this where a green result is load-bearing: coverage gates, security
scans, migration and deploy steps, anything whose passing lets work merge. Don't
re-litigate every exit code — a lint run that reports 40 files clean is just
clean.

*Why:* a test toolchain on a previous machine was broken for ~7 weeks while
every surface reported green, and the tell was there the whole time in the
counts. `hooks/tooling-rot-siren.sh` is the mechanical half of this; the
paragraph above is the judgment half.

## 3. No commit, no green status

An artifact or deliverable "exists" or is DONE only when it is (a) committed to
a repository AND (b) documented with a link to that repo/commit — neither alone
counts.

Prototypes and exploratory AI-session output are **design input, never
capability**: use them freely for ideas, but never record them in status tables,
coverage percentages, or capacity plans — keep them under an explicit "design
intent" heading instead. Demonstration ≠ delivery; "runs green in my session" is
not a status. Any status or progress claim should make the backing commit
reachable from it.

## 4. NEVER ignore failures

Even ones unrelated to the current change. If a failure can't be resolved in the
session, open a tracking issue to follow it up. Do not narrow the scope of
"passing" to mean "the part I touched passes".

## 5. End long turns with a "Where we are" trail marker

I run several agent instances across two laptops, so I come back to a session
cold and cannot reconstruct it without scrolling to my own last prompt. That
reconstruction gap is how scope drift and unanswered blockers go unnoticed until
they become defects.

**Fire it when:** (a) the turn was long or multi-phase — substantial tool work,
a scope change, or more than one deliverable; or (b) findings contradict the
plan I approved. Do *not* fire it on short conversational turns; a trail marker
on every reply is noise, and noise is why the last one stopped being read.

```
─────────────────────────────────────────────
↩︎ <repo>  ·  <HH:MM>
─────────────────────────────────────────────
⚠ Changed since you decided:
  <only if true: surprises, scope drift, a
   decision new evidence undercuts>

▸ NEEDS YOU (n):
  1. <the decision or blocker, options inline>

Next without you: <what proceeds unblocked>
─────────────────────────────────────────────
```

Plain text in chat, never a rendered widget — it must be readable instantly and
on any device.

**Length is the failure mode.** No recap of my prompt, the decisions I already
made, the path taken, or what shipped — I can scroll or ask for any of that, and
a marker long enough to skim gets skimmed, which reads as "all good" and is
exactly the false-green pattern this exists to prevent. Three sections, nothing
above them but the repo line.

Rules for it: **self-contained** — name branches, PR/issue numbers, never "the
script" or "that fix". **Omit empty sections** rather than printing "none"; if
nothing changed and nothing needs me, it is just the `Next` line. Keep `NEEDS
YOU` to real asks with options stated inline. `Changed since you decided` is the
highest-value section — that is what catches drift, so never soften or bury it.

## 6. Reviewing someone else's PR ends with a recorded verdict

When reviewing a PR that is mine to review (not mine to author), the deliverable
is one formal review submission posted **atomically with the findings**:

```bash
gh pr review --approve|--request-changes --body-file <findings>
```

The detailed findings as the review body and the matching verdict flag on the
*same call* — never a plain comment now with the verdict "left for later". State
the verdict up front in the body so prose and CTA always align (clean or
nit-only → approve; must-fix findings → request changes). Then report back with
links.

Only stop short of the verdict if I explicitly say comments-only, or if the
findings are so uncertain the verdict itself needs my judgment — and say so
explicitly rather than silently leaving it undone.

## 7. Scope, PII, and craft

- **Stay within scope.** Flag adjacent problems; don't silently fix them.
- **Be cautious of PII/PHI** — never commit, log, or paste it into outputs;
  redact when in doubt. This includes config files: permission allowlists and
  settings have a way of accumulating pasted payload data.
- **Keep code concise but readable.**
- **Document the *why*** — decisions, trade-offs, non-obvious logic, and public
  interfaces. Not every line.

## 8. Turn repeatable work into skills — sized by blast radius

Always look for repeatable tasks that could become skills, and pick the scope by
who benefits:

| Who benefits | Where it goes |
|---|---|
| Only me | Local skill (`~/.claude/skills/`) |
| One project or team | Project-level skill (`.claude/skills/` in the repo) |
| More than one team | Shared internal plugin/marketplace |
| Beyond the org | Public plugin |

## 9. Teachable moments

Give a human-readable summary of changes and *why*, plus expected outcomes
(faster runtimes, more stability, false-fail vs. real bug in the system under
test). I'd rather understand the change than just receive it.

## 10. Keep an eye out for new tooling

Fast-growing frameworks, new MCP servers, new skills — worth adopting. But don't
swap tooling mid-task without flagging it first.

## 11. HAVE FUN

Sneak in geeky fun where it fits (custom test reporters, themed output). If
something gets wider adoption, polish it to whatever styleguide applies.

---

# Repo Conventions

Defaults for when a repo is silent. **Repo-local config always wins.**

## Environment & tooling

- **Node version:** check for a pin (`.nvmrc` / `.tool-versions`) and `nvm use`
  (or asdf/mise) before installing or building. Never assume the global version.
- **Package manager:** respect the repo's lockfile — pnpm, yarn, and npm are all
  in play. Never migrate a repo between package managers.

## Commits & branches

- **Commits:** Conventional Commits — `type(scope): summary`, types
  `feat|fix|docs|style|refactor|test|chore|perf`.
- **Branches:** `<prefix>/<kebab-slug>`, ≤60 chars, optional leading ticket id
  (e.g. `feat/42-add-x`). Prefixes: `feat|fix|chore|docs|refactor|test|perf`.
  `main`, `release/*`, and bot branches are exempt.
- Branch off the latest `main` (or the repo's target branch) — fetch remote
  first, at minimum at task start, before branching, and before pushing.

## Concurrency & worktrees

**Isolated worktrees are the default for concurrent work.** When more than one
session or agent may touch the same repo, each gets its own:

```bash
git worktree add ../<repo>-<slug> <branch>
```

Never share a single working directory. A shared tree lets one process's
`checkout` / `add -A` move the tree and index out from under another
mid-operation — that is a real bug I have hit, where an amend captured a peer
session's uncommitted file.

**Before starting in a repo, assume a peer session may be active:** check
`git branch --show-current` and the `git stash list` count first, so you can
tell pre-existing state from your own. Prefer a fresh worktree over switching
branches in place. Spawned agents that mutate files should run with
`isolation: "worktree"`.

## Quality gates

- **Never bypass hooks** with `--no-verify`. Fix the underlying lint / typecheck
  / test failure instead.
- **Four-gate check before "done" or opening a PR:** build + typecheck + lint +
  test must all pass. Treat `typecheck` as a first-class gate distinct from lint.

## Docs

- **`AGENTS.md` is the canonical knowledge map** — read it first for
  architecture and conventions. `CLAUDE.md` / `GEMINI.md` in a repo should be
  thin pointers to it; don't duplicate doc content between them, or they drift.

---

# Standard Workflow

```
start task
  → fetch remote, branch off latest main  (feature/<name>)
  → plan / brainstorm  (visual first — rule 1)
  → implement
  → test the changes  (unit minimum; strive for more levels)
  → review passes  (code review, test review, security)
  → resolve flagged issues
  → final checks on the latest version  (four gates — not the pre-fix run)
  → commit, push, PR
  → merge once green
```

Rule 4 applies at every step: an unrelated failure surfaced along the way still
gets resolved or filed, never stepped over.
