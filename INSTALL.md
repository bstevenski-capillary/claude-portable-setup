# Install

For the agent running this: work through the four steps below in order. **Never
overwrite an existing file without showing the user a diff and getting a yes** —
this machine may already have a config worth keeping.

Paths below assume the bundle is the current directory.

---

## 1. Global working rules — two files, not one

The rules are split by **audience**, not by topic:

```
~/.config/ai-rules/global.md   ← agent-agnostic. Claude, Gemini, Codex, Copilot
                                  all read this same file.
~/.claude/CLAUDE.md            ← Claude Code only: skills, hooks, settings keys,
                                  tool behavior. Starts with an @import of the
                                  shared file.
```

```bash
mkdir -p ~/.config/ai-rules ~/.claude
```

- If `~/.config/ai-rules/global.md` **does not exist** → copy
  `home/ai-rules/global.md` there.
- If `~/.claude/CLAUDE.md` **does not exist** → copy `home/CLAUDE.md` there.
- If either **does exist** → show the user a diff and ask whether to merge,
  replace, or skip. Do not silently clobber.

Point the other agents at the shared file too — each reads its own filename, so
a symlink is the cheapest way to keep them from drifting apart:

```bash
ln -s ~/.config/ai-rules/global.md ~/.gemini/GEMINI.md   # and AGENTS.md, etc.
```

**Why split at all.** The single-file version drifted: a rule got improved while
answering a Claude question, and the copy the other three agents read stayed
wrong. One file with one owner is the fix. The cost is that every rule now has
to earn its place on one side of the line — anything naming a skill, hook, or
`settings.json` key belongs in `CLAUDE.md`, everything else in `global.md`.

**Verify the import resolved.** `CLAUDE.md` line 6 is
`@~/.config/ai-rules/global.md`; a failed import is silent, and silence here
looks exactly like a machine with no rules. In a new session, ask the agent to
state rule 3 — it should answer **"always do TDD"**, which only exists in the
shared file. If it can't, replace the `~` with the absolute home path and retry.

## 2. The visual-decisions skill

```bash
mkdir -p ~/.claude/skills
cp -R home/skills/visual-decisions ~/.claude/skills/
```

Verify it registers: it should appear in the skill listing as
`visual-decisions` in a new session.

## 3. The tooling-rot siren

```bash
mkdir -p ~/.claude/hooks
cp home/hooks/tooling-rot-siren.sh ~/.claude/hooks/
cp home/hooks/rot-watch.example.json ~/.claude/hooks/
chmod +x ~/.claude/hooks/tooling-rot-siren.sh
```

The hook is **silent until configured** — with no `rot-watch.json` it exits
immediately. That's intended: nothing was asked for, so nothing is claimed.

To turn it on, copy the example to `~/.claude/hooks/rot-watch.json` and list the
plugins/CLIs worth watching on this machine. A watchlist that exists but is
empty **will** report itself — coverage was intended and isn't there.

### What it checks

| Key | Compares | Network |
|---|---|---|
| `plugin` | installed **and** enabled in `settings.json` | no |
| `marketplace` | git checkout age vs `stale_days` | no |
| `cli` | on PATH, and `--version` vs the plugin version | no |
| `npm` | installed version vs the registry's `latest` | **cached only** |

The first three compare local things to each other, so a machine can be
perfectly self-consistent and still be a year behind the registry. `npm` closes
that gap — but it never blocks SessionStart. It reads
`~/.claude/hooks/.rot-npm-cache.json`; when that is absent or older than
`npm_ttl_hours` (default 24) it dispatches a **detached** refresh for the next
session. Consequences worth knowing:

- The first session after adding an `npm` key reports `cannot verify (no cached
  data yet)`. The session after that reports real drift. That is the honest
  sequence, not a bug.
- Offline degrades to *stale data, explicitly labelled with its age* — never to
  silence. A blocking `npm view` would instead hit the 10s hook timeout and be
  killed mid-run, printing nothing, which is indistinguishable from all-clear.

### Testing it

The repo ships executable tests — run these against the working copy:

```bash
./tests/test-siren.sh
```

17 cases covering the abstention path, field-shift regressions, npm drift, and
the no-network-on-the-hot-path contract. Every bug that has escaped this hook
has a case there.

The probes below are different and still worth running once: they exercise the
**deployed** copy at `~/.claude/hooks/`, catching install-time problems (wrong
path, missing exec bit, stale copy) that a test against the repo cannot see.
**Both are required** — the empty-watchlist probe alone has a zero denominator:
it only exercises the "nothing to check" path and never once parses a real watch
entry, which is exactly how two parsing bugs shipped in this hook.

**Probe 1 — the abstention path:**

```bash
printf '{"watch":[]}' > /tmp/rot-empty.json && \
  CONFIG=/tmp/rot-empty.json bash -c 'cp /tmp/rot-empty.json ~/.claude/hooks/rot-watch.json; ~/.claude/hooks/tooling-rot-siren.sh; rm ~/.claude/hooks/rot-watch.json'
```

Expect JSON on stdout containing `TOOLING-ROT SIREN — empty watchlist`. If you
get nothing, the hook is not working — fix that before trusting it.

**Probe 2 — the parsing path.** Three entries, each omitting a different key,
plus one CLI that cannot exist:

```bash
printf '{"watch":[{"plugin":"ghost@nowhere","marketplace":"nowhere","cli":"nope-1"},{"marketplace":"nowhere","cli":"nope-2"},{"cli":"nope-3"}]}' \
  > ~/.claude/hooks/rot-watch.json
~/.claude/hooks/tooling-rot-siren.sh; rm ~/.claude/hooks/rot-watch.json
```

Expect **`across 6 check(s)`** and a `CLI 'nope-N' not on PATH` finding for all
three of `nope-1`, `nope-2`, `nope-3`. Two specific failures to watch for:

- **Fewer than 6 checks, or a missing `nope-3`** — entries are being dropped.
  Something in the loop body is consuming the watchlist on stdin (an MCP stdio
  server that ignores `--version` will do this). The loop must read on FD 3.
- **Findings naming the wrong field** (e.g. a marketplace check against
  `nope-2`, or `CLI '14' not on PATH`) — fields are shifting left because the
  delimiter is IFS whitespace. It must be `\x1f`, not a tab.

A watched "CLI" that is actually an MCP stdio server is the common trigger for
the first failure — probe 2 is what catches it.

**Probe 3 — the deployed copy can refresh its own npm cache.** The refresh runs
detached with its output closed, so a failure here is invisible by construction:

```bash
bash ~/.claude/hooks/tooling-rot-siren.sh --refresh-npm-cache npm
cat ~/.claude/hooks/.rot-npm-cache.json
```

Expect a `npm` entry with a `latest` and a fresh `checked` timestamp. Nothing
written means the deployed hook cannot refresh, and every later npm finding will
be based on data frozen at install time.

## 4. Settings

`home/settings.template.json` is a **template, not a drop-in** — it carries
`_comment` keys for readability that should be stripped, and its plugin list
should be reconciled with whatever is already installed here.

- If `~/.claude/settings.json` does not exist → strip the `_comment` keys and
  write it.
- If it exists → merge key by key, showing the user what changes. Preserve any
  existing `permissions.allow` entries; do not import an allowlist from
  elsewhere (see EXCLUDED.md for why).

Then install the plugins listed under `enabledPlugins`:

```bash
claude plugin install <plugin-id>
```

All of them are from the public `claude-plugins-official` marketplace. Install
what's actually useful here rather than all of them reflexively — a bloated
skill listing makes the right skill harder to pick, which is the problem
`skillOverrides` exists to solve.

## 5. Memory seed (optional)

The memory directory is per-project and named after the project path, so it
can't be copied blind. Once a project directory exists at
`~/.claude/projects/<slug>/memory/`, copy `home/memory/*` into it — or just let
the agent re-derive the fact, since shared rule 1 in
`~/.config/ai-rules/global.md` already states it.

---

## Verify

- [ ] A new session lists `visual-decisions` among available skills
- [ ] The agent can state rule 3 as "always do TDD" — proves the `@import` of
      `~/.config/ai-rules/global.md` resolved rather than failing silently
- [ ] The siren smoke-test above printed the empty-watchlist finding
- [ ] `~/.claude/settings.json` parses (`python3 -m json.tool ~/.claude/settings.json`)
- [ ] No `_comment` keys survived into the live settings file
- [ ] The agent renders a visual before the next decision it puts to you —
      that's the real acceptance test for this whole bundle
