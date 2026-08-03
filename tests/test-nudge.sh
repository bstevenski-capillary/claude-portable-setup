#!/bin/bash
# Executable tests for clear-nudge.sh.
#
# Why these exist: this hook's entire job is to distinguish "a task boundary
# actually happened" from "a string that looks like one went past". It shipped
# a false positive doing exactly that — it keyed on the command's INTENT and
# announced a commit that never happened, and the false report was relayed to
# the user as advice. A hook that lies about task boundaries is worse than no
# hook, so every distinguishing case gets pinned here.
#
# The hook fires only when BOTH hold: a boundary is evidenced in the tool's own
# output, AND context is already expensive. Both halves are tested, in both
# directions — a nudge that fires unconditionally becomes wallpaper, which is
# the failure mode that retired the built-in indicator.
#
#   ./tests/test-nudge.sh
#
set -u

HOOK="$(cd "$(dirname "$0")/.." && pwd)/home/hooks/clear-nudge.sh"
PASS=0
FAIL=0
FAILED_NAMES=()

# ── plumage ──────────────────────────────────────────────────────────────────
C_DIM=$'\033[38;2;85;85;85m'; C_GOLD=$'\033[38;2;240;192;64m'
C_RED=$'\033[38;2;220;80;80m'; C_OFF=$'\033[0m'

banner() {
  printf '%s\n' "  ${C_GOLD}◆${C_OFF}   ${C_GOLD}nudge${C_OFF} ${C_DIM}· task-boundary regression flock${C_OFF}"
  printf '%s\n' " ${C_GOLD}◆▬◆${C_OFF}  ${C_DIM}$HOOK${C_OFF}"
  printf '%s\n\n' "  ${C_DIM}▀${C_OFF}"
}

ok()   { PASS=$((PASS+1)); printf '  %s✔%s %s\n' "$C_GOLD" "$C_OFF" "$1"; }
bad()  { FAIL=$((FAIL+1)); FAILED_NAMES+=("$1")
         printf '  %s✘ %s%s\n' "$C_RED" "$1" "$C_OFF"
         printf '    %sexpected:%s %s\n' "$C_DIM" "$C_OFF" "$2"
         printf '    %sgot:%s      %s\n' "$C_DIM" "$C_OFF" "${3:0:400}"; }

# ── fixtures ─────────────────────────────────────────────────────────────────
# A synthetic transcript supplies the context size. The hook derives context
# from the LAST non-sidechain usage record — the number the API actually
# billed — so the fixture writes real usage records rather than a bare integer.
setup() { TMP=$(mktemp -d); }
teardown() { [ -n "${TMP:-}" ] && rm -rf "$TMP"; }

# transcript <main_ctx_tokens> [sidechain_ctx_tokens]
# The optional second record is a sidechain (subagent) turn. It is written AFTER
# the main one precisely so a naive "last record wins" reader would pick it up.
transcript() {
  python3 -c '
import json, sys
path, main = sys.argv[1], int(sys.argv[2])
side = int(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3] else None
recs = [{"message": {"usage": {"input_tokens": 0, "cache_read_input_tokens": main,
                               "cache_creation_input_tokens": 0, "output_tokens": 100}}}]
if side is not None:
    recs.append({"isSidechain": True,
                 "message": {"usage": {"input_tokens": 0, "cache_read_input_tokens": side,
                                       "cache_creation_input_tokens": 0, "output_tokens": 10}}})
with open(path, "w") as fh:
    for r in recs:
        fh.write(json.dumps(r) + "\n")
' "$TMP/transcript.jsonl" "$1" "${2:-}"
}

# run_nudge <command> <combined-output> <ctx-tokens> [is_error]
run_nudge() {
  transcript "$3"
  python3 -c '
import json, sys
cmd, out, tp, err = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4] == "1"
print(json.dumps({
    "tool_name": "Bash",
    "tool_input": {"command": cmd},
    "tool_response": {"stdout": out, "stderr": "", "is_error": err},
    "transcript_path": tp,
}))
' "$1" "$2" "$TMP/transcript.jsonl" "${4:-0}" | bash "$HOOK" 2>&1
}

BIG=150000     # comfortably over the 100k threshold
SMALL=40000    # comfortably under it

assert_fires()  { case "$2" in *"CONTEXT CHECKPOINT"*) ok "$3";;
                              *) bad "$3" "hook fires (CONTEXT CHECKPOINT)" "$2";; esac; }
assert_silent() { [ -z "$2" ] && ok "$3" || bad "$3" "no output at all" "$2"; }
assert_has()    { case "$2" in *"$1"*) ok "$3";; *) bad "$3" "output contains '$1'" "$2";; esac; }

banner

# ── 1. wrong tool → not our business ─────────────────────────────────────────
setup
transcript "$BIG"
OUT=$(printf '{"tool_name":"Read","tool_input":{},"tool_response":{},"transcript_path":"%s"}' \
      "$TMP/transcript.jsonl" | bash "$HOOK" 2>&1)
assert_silent x "$OUT" "non-Bash tool → silent"
teardown

# ── 2. malformed payload must never crash a PostToolUse hook ────────────────
setup
OUT=$(printf 'not json at all' | bash "$HOOK" 2>&1)
RC=$?
[ "$RC" -eq 0 ] && [ -z "$OUT" ] && ok "garbage payload → exit 0, silent" \
  || bad "garbage payload → exit 0, silent" "rc=0 and empty" "rc=$RC out=$OUT"
teardown

# ── 3. THE REGRESSION: intent without evidence must not fire ────────────────
# The shipped bug. `"git commit" in cmd` fired on a payload that merely QUOTED
# the string. A grep, an echo, a doc example, and a test fixture all contain it.
setup
OUT=$(run_nudge 'grep -rn "git commit" tests/' 'tests/test-nudge.sh:42: git commit' "$BIG")
assert_silent x "$OUT" "grep FOR 'git commit' → silent (intent ≠ evidence)"
teardown

setup
OUT=$(run_nudge "echo 'git commit -m x'" 'git commit -m x' "$BIG")
assert_silent x "$OUT" "echoing a commit command → silent"
teardown

# ── 4. a real commit with real evidence, over threshold → fires ─────────────
setup
OUT=$(run_nudge 'git commit -m "feat: x"' '[main 921c83e] feat: x
 1 file changed, 2 insertions(+)' "$BIG")
assert_fires x "$OUT" "real commit + big context → fires"
assert_has "commit" "$OUT" "  names the boundary kind"
teardown

# ── 5. both conditions are required: real commit, cheap context → silent ────
# Firing on every boundary regardless of cost is how a nudge becomes wallpaper.
setup
OUT=$(run_nudge 'git commit -m "feat: x"' '[main 921c83e] feat: x' "$SMALL")
assert_silent x "$OUT" "real commit + small context → silent (nothing to save)"
teardown

# ── 6. compound commands: one failed part disqualifies the whole call ───────
# Observed live. `a; b` reports a SINGLE exit status, so a failed push chained
# with a succeeding command arrives as is_error=false, and the second command's
# output supplies bogus "evidence" for the first.
setup
OUT=$(run_nudge 'git push origin feat/x; git branch -a' 'failed to push some refs
  origin/HEAD -> origin/main
  remotes/origin/main' "$BIG")
assert_silent x "$OUT" "failed push chained with a success → silent"
teardown

# ── 7. `->` alone is not a push. `git branch -a` prints it too. ─────────────
setup
OUT=$(run_nudge 'git push origin feat/x' '  origin/HEAD -> origin/main' "$BIG")
assert_silent x "$OUT" "arrow in output without a real ref transition → silent"
teardown

# ── 8. a genuine push reports a ref transition ──────────────────────────────
setup
OUT=$(run_nudge 'git push origin feat/x' 'To https://github.com/o/r.git
 * [new branch]      feat/x -> feat/x' "$BIG")
assert_fires x "$OUT" "real push (new branch + To line) → fires"
teardown

# ── 9. PR create → fires and is labelled as a PR, not a commit ─────────────
setup
OUT=$(run_nudge 'gh pr create --fill' 'https://github.com/o/r/pull/7' "$BIG")
assert_fires x "$OUT" "gh pr create → fires"
assert_has "PR" "$OUT" "  labelled PR"
teardown

# ── 10. silent success is genuine success for merge only ───────────────────
# `gh pr merge --admin` prints nothing when it works and exits non-zero when it
# does not — which the error guard already caught. So silence here is evidence.
setup
OUT=$(run_nudge 'gh pr merge 7 --admin --squash' '' "$BIG")
assert_fires x "$OUT" "gh pr merge with empty output → fires (exit code is the evidence)"
assert_has "merge" "$OUT" "  labelled merge"
teardown

# ── 11. ...but silence is NOT evidence for a commit ────────────────────────
# Only merge opts into silent-success. Generalising that would make every
# no-output command a boundary.
setup
OUT=$(run_nudge 'git commit -m x' '' "$BIG")
assert_silent x "$OUT" "commit with empty output → silent (no evidence)"
teardown

# ── 12. explicit tool error → silent regardless of output ──────────────────
setup
OUT=$(run_nudge 'git commit -m x' '[main 921c83e] x' "$BIG" 1)
assert_silent x "$OUT" "is_error=true → silent even with matching evidence"
teardown

# ── 13. 'nothing to commit' is a no-op, not a boundary ─────────────────────
setup
OUT=$(run_nudge 'git commit -m x' 'nothing to commit, working tree clean' "$BIG")
assert_silent x "$OUT" "nothing to commit → silent"
teardown

# ── 14. sidechain turns must not be read as main-thread context ────────────
# Subagent usage records land in the same transcript. Counting them as the live
# context lets a small subagent turn mask a huge main context (or vice versa).
# Main is over threshold, sidechain is under and written LAST.
setup
OUT=$(run_nudge 'git commit -m x' '[main 921c83e] x' "$BIG" 0)
transcript "$BIG" "$SMALL"
OUT=$(python3 -c '
import json,sys
print(json.dumps({"tool_name":"Bash","tool_input":{"command":"git commit -m x"},
 "tool_response":{"stdout":"[main 921c83e] x","stderr":"","is_error":False},
 "transcript_path":sys.argv[1]}))' "$TMP/transcript.jsonl" | bash "$HOOK" 2>&1)
assert_fires x "$OUT" "trailing sidechain record does not mask main-thread context"
teardown

# ── 15. missing transcript → degrade to silence, never to a crash ──────────
setup
OUT=$(python3 -c '
import json
print(json.dumps({"tool_name":"Bash","tool_input":{"command":"git commit -m x"},
 "tool_response":{"stdout":"[main 921c83e] x","stderr":"","is_error":False},
 "transcript_path":"/nonexistent/path.jsonl"}))' | bash "$HOOK" 2>&1)
assert_silent x "$OUT" "unreadable transcript → silent, no traceback"
teardown

# ── report ───────────────────────────────────────────────────────────────────
printf '\n  %s────────────────────────────────────────%s\n' "$C_DIM" "$C_OFF"
if [ "$FAIL" -eq 0 ]; then
  printf '  %s◆ all %d checks held the line%s\n\n' "$C_GOLD" "$PASS" "$C_OFF"
  exit 0
fi
printf '  %s✘ %d failed%s, %d passed\n' "$C_RED" "$FAIL" "$C_OFF" "$PASS"
for n in "${FAILED_NAMES[@]}"; do printf '      %s- %s%s\n' "$C_DIM" "$n" "$C_OFF"; done
printf '\n'
exit 1
