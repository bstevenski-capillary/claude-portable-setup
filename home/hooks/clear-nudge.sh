#!/bin/bash
# PostToolUse nudge: suggest /clear at the ONE moment it is free.
#
# The corner context indicator is passive, so it gets noticed several tasks too
# late. This fires only when BOTH are true:
#   1. a commit or PR-create just SUCCEEDED — the work is banked, so clearing
#      loses nothing, and
#   2. context is already large enough that carrying it forward is expensive.
#
# Both conditions matter. Firing on every threshold crossing (regardless of what
# you are mid-way through) is how a warning becomes wallpaper — which is exactly
# how the built-in indicator stopped working.
set -u

INPUT=$(cat)

python3 - "$INPUT" <<'EOF'
import json, sys

try:
    p = json.loads(sys.argv[1])
except Exception:
    sys.exit(0)

if p.get("tool_name") != "Bash":
    sys.exit(0)

cmd = ((p.get("tool_input") or {}).get("command") or "")

resp = p.get("tool_response") or {}
if isinstance(resp, dict):
    if resp.get("is_error") or resp.get("interrupted"):
        sys.exit(0)
    out = str(resp.get("stdout", "")) + "\n" + str(resp.get("stderr", ""))
else:
    out = str(resp)

# Task boundaries require BOTH the intent (command ran) and the EVIDENCE (the
# tool actually reported doing it).
#
# Intent alone is not enough, and this is not hypothetical: keying on
# `"git commit" in cmd` made the hook fire on a test payload that merely
# quoted the string, announcing a commit that never happened — and the false
# report was then relayed to the user as advice. A grep, an echo, a doc
# example, or a test fixture all contain the same substring. Only the tool's
# own output distinguishes "was asked to" from "did".
import re

# Any error text disqualifies the whole call. Compound commands (`a; b; c`)
# report a single exit status, so a FAILED push chained with a succeeding
# command still arrives as is_error=false — observed live, where a failed
# branch-delete was chained with `git branch -a` whose output supplied bogus
# "evidence". When any part errored, we cannot attribute success to any part.
if re.search(r"(?m)^error:|failed to push|!\s*\[rejected\]|nothing to commit"
             r"|Everything up-to-date", out):
    sys.exit(0)


def at_command_position(verb):
    """True only if `verb` starts a command, not if it merely appears inside a
    quoted string, grep pattern, or echoed example."""
    return re.search(r"(?:^|&&|\|\||;|\||\bthen\b|\bdo\b)\s*" + re.escape(verb), cmd)


BOUNDARIES = (
    # (verb, regex the output must match, label, may-succeed-silently)
    ("git commit",   r"\[[^\]\s]+\s+[0-9a-f]{7,}\]",                    "commit", False),
    ("gh pr create", r"github\.com/[^/\s]+/[^/\s]+/pull/\d+",           "PR",     False),
    # `gh pr merge --admin` prints nothing on success; gh exits non-zero on
    # failure, which the error guard above already caught. So silence here is
    # genuine success, not absent evidence.
    ("gh pr merge",  r"Merged pull request|✓\s*Merged|^\s*$",           "merge",  True),
    # Real push reports name a ref transition or a new ref. `->` alone is far
    # too loose: `git branch -a` prints `origin/HEAD -> origin/main`.
    ("git push",     r"(?m)\[new (branch|tag)\]|[0-9a-f]{7,}\.\.[0-9a-f]{7,}"
                     r"|^To (https://|git@|ssh://)",                    "push",   False),
)

kind = None
for verb, ev, label, silent_ok in BOUNDARIES:
    if not at_command_position(verb):
        continue
    if re.search(ev, out) or (silent_ok and not out.strip()):
        kind = label
        break
if not kind:
    sys.exit(0)

# Live context from the last main-thread usage record — the billed number.
ctx = 0
try:
    with open(p.get("transcript_path", ""), errors="ignore") as fh:
        for line in fh:
            if '"usage"' not in line:
                continue
            try:
                rec = json.loads(line)
            except Exception:
                continue
            if rec.get("isSidechain"):
                continue
            u = (rec.get("message") or {}).get("usage") or rec.get("usage")
            if u:
                ctx = (u.get("input_tokens", 0)
                       + u.get("cache_read_input_tokens", 0)
                       + u.get("cache_creation_input_tokens", 0))
except Exception:
    pass

THRESHOLD = 100_000          # half a 200k window; below this, carrying on is cheap
if ctx < THRESHOLD:
    sys.exit(0)

pct = ctx / 200_000 * 100
# Every future turn re-reads this context; at the 0.1x cache-read weight that is
# what each additional reply costs before it produces anything.
per_turn = ctx * 0.1

msg = (
    f"Context is {ctx/1000:.0f}k ({pct:.0f}%) and a {kind} just landed — "
    f"the work is banked, so /clear is free right now. "
    f"Carrying this forward costs ~{per_turn/1000:.0f}k weighted tokens per turn "
    f"before any reply is generated."
)

print(json.dumps({
    "systemMessage": f"▸ {msg}",
    "hookSpecificOutput": {
        "hookEventName": "PostToolUse",
        "additionalContext": (
            "CONTEXT CHECKPOINT: " + msg +
            " If the user's next request starts a genuinely new task, suggest /clear "
            "in one short line before beginning it. If they are continuing the same "
            "thread of work, say nothing — do not nag."
        ),
    },
}))
EOF
