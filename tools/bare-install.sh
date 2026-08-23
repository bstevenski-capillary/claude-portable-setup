#!/bin/bash
# Carry out INSTALL.md §§1–4 into a scratch $HOME, then prove it landed.
#
# Why this exists: this is SC-3. `tools/check-drift.sh` reserves exit **2** for
# "nothing of this bundle is installed at this root, so nothing was compared" —
# an abstention. A CI job that shelled out to the drift check and accepted any
# non-1 status would therefore go green on an install that copied *zero files*,
# and the report would be indistinguishable from a real pass. So this script
# demands exit 0 specifically, and treats 2 as the failure it is.
#
# What it proves, in one sentence: a stranger with no ~/.claude, no overlay, and
# nothing of the author's on their machine can run INSTALL.md and end up with a
# working core (STRATEGY.md, "Who it's for"). Every other suite in this repo
# exercises the artifacts; this one exercises the act of installing them.
#
# Read-only with respect to the real $HOME. With no argument it installs into a
# fresh `mktemp -d` and removes it afterwards; given a path, it installs there
# and leaves it alone, because a script that deletes a directory a caller handed
# it is a worse tool than one that only cleans up after itself.
#
#   ./tools/bare-install.sh            # scratch root, cleaned up
#   ./tools/bare-install.sh /tmp/probe # your root, left in place
#
set -u

BUNDLE="$(cd "$(dirname "$0")/.." && pwd)"
STATUS=0

# OWNED_TMP is the whole reason the cleanup trap is safe: it fires only for a
# root this script created. A caller-supplied path is never removed.
if [ "$#" -ge 1 ]; then
  ROOT="$1"
  OWNED_TMP=0
else
  ROOT="$(mktemp -d)"
  OWNED_TMP=1
fi

# Inlined rather than written as a cleanup() function: shellcheck cannot see
# that a trap invokes one, so the function form raises SC2329 and this repo
# requires tools to be clean at shellcheck's *default* severity. Single quotes
# are deliberate — the body is evaluated when the trap fires, not now.
trap '[ "$OWNED_TMP" -eq 1 ] && rm -rf "$ROOT"' EXIT

printf 'scratch root: %s\n' "$ROOT"

# ── the install, mirroring INSTALL.md §§1–4 ──────────────────────────────────
# §1's "never overwrite without asking" cannot trigger here: a scratch $HOME is
# empty by construction, which is exactly the condition this job is testing.
mkdir -p "$ROOT/.config/ai-rules" "$ROOT/.claude/hooks" "$ROOT/.claude/skills"

cp "$BUNDLE/home/CLAUDE.md"          "$ROOT/.claude/CLAUDE.md"          # §1
cp "$BUNDLE/home/ai-rules/global.md" "$ROOT/.config/ai-rules/global.md" # §1
cp -R "$BUNDLE/home/skills/visual-decisions" "$ROOT/.claude/skills/"    # §2

# Glob, not a hardcoded list: check-drift compares the hooks directory in BOTH
# directions, so a file added to home/hooks/ and missed here surfaces as
# "missing" rather than passing quietly. The glob keeps this script from
# becoming a second file list that can go stale (§3, §4).
cp "$BUNDLE"/home/hooks/*            "$ROOT/.claude/hooks/"

# A deployed hook without +x never runs, and Claude Code reports nothing when a
# hook fails to execute — so the session silently loses that hook's coverage.
# Scoped to *.sh because rot-watch.example.json ships 0644 on purpose.
chmod +x "$ROOT"/.claude/hooks/*.sh

# Deliberately NOT installed: settings.json (§5) and the memory/ seeds (§6).
# The drift check does not compare either — the template ships an empty
# allowlist while a live file grows entries, and seeds accumulate — so
# installing them here would claim coverage this verification does not have.

# ── the verification ─────────────────────────────────────────────────────────
OUT=$(CHECK_ROOT="$ROOT" bash "$BUNDLE/tools/check-drift.sh" 2>&1)
rc=$?
printf '%s\n' "$OUT"

case "$rc" in
  0) printf '⌂ bare install verified — drift check exited 0\n' ;;
  2) printf '✘ exit 2: nothing of the bundle was found under %s,\n' "$ROOT"
     printf '  so nothing was compared. That is an abstention, not a pass —\n'
     printf '  SC-3 requires exit 0, and an exit of 2 proves nothing at all.\n'
     STATUS=1 ;;
  *) printf '✘ drift check exited %s\n' "$rc"
     STATUS=1 ;;
esac

exit "$STATUS"
