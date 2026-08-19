# Install

For the agent running this: work through the four steps below in order. **Never
overwrite an existing file without showing the user a diff and getting a yes** —
this machine may already have a config worth keeping.

Paths below assume the bundle is the current directory.

---

## 1. Global working rules

```bash
mkdir -p ~/.claude
```

- If `~/.claude/CLAUDE.md` **does not exist** → copy `home/CLAUDE.md` there.
- If it **does exist** → show the user a diff and ask whether to merge, replace,
  or skip. Do not silently clobber it.

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

Smoke-test it (this is the "does a deliberate failure actually fail it" probe —
worth doing once, since a hook that silently no-ops looks identical to a healthy
one):

```bash
printf '{"watch":[]}' > /tmp/rot-empty.json && \
  CONFIG=/tmp/rot-empty.json bash -c 'cp /tmp/rot-empty.json ~/.claude/hooks/rot-watch.json; ~/.claude/hooks/tooling-rot-siren.sh; rm ~/.claude/hooks/rot-watch.json'
```

Expect JSON on stdout containing `TOOLING-ROT SIREN — empty watchlist`. If you
get nothing, the hook is not working — fix that before trusting it.

## 4. The rules-drift check

```bash
cp home/hooks/claude-md-drift.sh ~/.claude/hooks/
cp home/hooks/claude-md-drift.example.json ~/.claude/hooks/
chmod +x ~/.claude/hooks/claude-md-drift.sh
```

This one answers "have my global rules changed since the bundle was last
reconciled against them?" — because the live `~/.claude/CLAUDE.md` and this
bundle's copy are *deliberately* different documents (the live one names
employer, client, and internal tooling; see EXCLUDED.md). A plain diff would
therefore fire every session and get trained away, so the check compares each
file against a fingerprint recorded in `home/hooks/claude-md-baseline.json` and
speaks up only when one of them has actually moved.

Turn it on by copying the example to `~/.claude/hooks/claude-md-drift.json` and
pointing `bundle` at this checkout. With no config it exits silently.

Register it alongside the siren under `hooks.SessionStart` in settings.

Smoke-test that it can actually fail — a check that only ever passes is
indistinguishable from one that never runs:

```bash
cp ~/.claude/CLAUDE.md /tmp/live.bak && echo "# drift probe" >> ~/.claude/CLAUDE.md
~/.claude/hooks/claude-md-drift.sh   # expect: RULES-DRIFT — the portable bundle is stale
cp /tmp/live.bak ~/.claude/CLAUDE.md
~/.claude/hooks/claude-md-drift.sh   # expect: no output at all
```

**After any reconciliation, restamp the baseline** with both new sha256 values
(`shasum -a 256 ~/.claude/CLAUDE.md home/CLAUDE.md`) — otherwise the check keeps
reporting the change you already handled, which is how a useful alert becomes
noise.

## 5. Settings

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

## 6. Memory seed (optional)

The memory directory is per-project and named after the project path, so it
can't be copied blind. Once a project directory exists at
`~/.claude/projects/<slug>/memory/`, copy `home/memory/*` into it — or just let
the agent re-derive the fact, since `CLAUDE.md` rule 1 already states it.

---

## Verify

- [ ] A new session lists `visual-decisions` among available skills
- [ ] The siren smoke-test above printed the empty-watchlist finding
- [ ] The drift smoke-test fired on a modified rules file, and went silent again once restored
- [ ] `~/.claude/settings.json` parses (`python3 -m json.tool ~/.claude/settings.json`)
- [ ] No `_comment` keys survived into the live settings file
- [ ] The agent renders a visual before the next decision it puts to you —
      that's the real acceptance test for this whole bundle
