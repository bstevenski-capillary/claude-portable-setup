#!/bin/bash
# Executable tests for statusline-context.sh.
#
# Why these exist: this is an INSTRUMENT, and a broken instrument is worse than
# no instrument — it reports a number you then trust. It runs on every turn
# against a transcript that grows unboundedly and contains records it must
# ignore (sidechains) and records it must survive (truncated final lines, since
# the file is being appended to while this reads it).
#
# The two things it must never do: crash (that blanks the statusline, removing
# the instrument silently), and under-report (which is the false-green shape
# this whole bundle exists to fight).
#
#   ./tests/test-statusline.sh
#
set -u

HOOK="$(cd "$(dirname "$0")/.." && pwd)/home/hooks/statusline-context.sh"
PASS=0
FAIL=0
FAILED_NAMES=()

# ── plumage ──────────────────────────────────────────────────────────────────
C_DIM=$'\033[38;2;85;85;85m'; C_GOLD=$'\033[38;2;240;192;64m'
C_RED=$'\033[38;2;220;80;80m'; C_OFF=$'\033[0m'

banner() {
  printf '%s\n' "  ${C_GOLD}▮${C_OFF}   ${C_GOLD}gauge${C_OFF} ${C_DIM}· statusline regression flock${C_OFF}"
  printf '%s\n' " ${C_GOLD}▮▮▮${C_OFF}  ${C_DIM}$HOOK${C_OFF}"
  printf '%s\n\n' "  ${C_DIM}▀${C_OFF}"
}

ok()   { PASS=$((PASS+1)); printf '  %s✔%s %s\n' "$C_GOLD" "$C_OFF" "$1"; }
bad()  { FAIL=$((FAIL+1)); FAILED_NAMES+=("$1")
         printf '  %s✘ %s%s\n' "$C_RED" "$1" "$C_OFF"
         printf '    %sexpected:%s %s\n' "$C_DIM" "$C_OFF" "$2"
         printf '    %sgot:%s      %s\n' "$C_DIM" "$C_OFF" "${3:0:400}"; }

# The colours under test, as the hook emits them. The colour IS the nudge, so a
# threshold regression is a silent loss of signal — worth pinning literally.
GREEN=$'\033[38;2;120;180;120m'
AMBER=$'\033[38;2;240;192;64m'
ALERT=$'\033[38;2;220;80;80m'

setup() { TMP=$(mktemp -d); }
teardown() { [ -n "${TMP:-}" ] && rm -rf "$TMP"; }

# add_rec <input> <cache_read> <cache_create> <output> [sidechain]
add_rec() {
  python3 -c '
import json, sys
path = sys.argv[1]
rec = {"message": {"usage": {"input_tokens": int(sys.argv[2]),
                             "cache_read_input_tokens": int(sys.argv[3]),
                             "cache_creation_input_tokens": int(sys.argv[4]),
                             "output_tokens": int(sys.argv[5])}}}
if len(sys.argv) > 6 and sys.argv[6] == "1":
    rec["isSidechain"] = True
open(path, "a").write(json.dumps(rec) + "\n")
' "$TMP/transcript.jsonl" "$2" "$3" "$4" "$5" "${6:-0}"
}

# run_status [transcript_path]
run_status() {
  python3 -c '
import json, sys
print(json.dumps({"transcript_path": sys.argv[1],
                  "model": {"display_name": "Opus 5"},
                  "workspace": {"current_dir": "/x/y/myrepo"}}))
' "${1:-$TMP/transcript.jsonl}" | bash "$HOOK" 2>&1
}

assert_has() { case "$2" in *"$1"*) ok "$3";; *) bad "$3" "output contains '$1'" "$2";; esac; }
assert_not() { case "$2" in *"$1"*) bad "$3" "output does NOT contain '$1'" "$2";; *) ok "$3";; esac; }

banner

# ── 1. garbage payload → a placeholder, never a crash ───────────────────────
# A statusline that dies prints nothing, and nothing is indistinguishable from
# "0% used" at a glance. It must always render something.
setup
OUT=$(printf 'not json' | bash "$HOOK" 2>&1)
assert_has "ctx" "$OUT" "garbage payload → renders a placeholder, not an empty line"
teardown

# ── 2. missing transcript → renders zeroed, does not traceback ─────────────
setup
OUT=$(run_status "/nonexistent/path.jsonl")
assert_has "0%" "$OUT" "unreadable transcript → renders 0%"
assert_not "Traceback" "$OUT" "  no python traceback leaks into the statusline"
teardown

# ── 3. context is the LAST main-thread record, not a sum ───────────────────
# Context is what the model saw on the latest request. Summing records would
# grow without bound and read as catastrophic within a few turns.
setup
add_rec x 0 40000 0 100
add_rec x 0 100000 0 100
OUT=$(run_status)
assert_has "50%" "$OUT" "ctx = last record (100k/200k = 50%), not the sum of records"
assert_has "100k" "$OUT" "  humanised as 100k"
teardown

# ── 4. burn DOES accumulate, and weights each token class ──────────────────
# out×5 + cache_create×1.25 + cache_read×0.1 + input×1.
# Here: 1000×5 + 100000×0.1 = 15000.
setup
add_rec x 0 100000 0 1000
OUT=$(run_status)
assert_has "burn 15k" "$OUT" "burn applies per-class billing weights"
teardown

# ── 5. sidechains: excluded from ctx, INCLUDED in burn ─────────────────────
# A subagent's tokens are really spent (so they belong in burn) but were never
# in the main thread's window (so they must not move the gauge). Getting this
# backwards is how a big subagent turn fakes a full context.
setup
add_rec x 0 100000 0 1000          # main   → burn 15000, ctx 100k
add_rec x 0 50000  0 200 1         # sidechain → burn +5000+1000
OUT=$(run_status)
assert_has "50%" "$OUT" "sidechain does not move the context gauge"
assert_has "burn 21k" "$OUT" "  but its tokens still count toward burn"
teardown

# ── 6. colour thresholds — the colour is the whole signal ──────────────────
setup; add_rec x 0 80000 0 10;  OUT=$(run_status)
assert_has "$GREEN" "$OUT" "40% → green"; teardown

setup; add_rec x 0 140000 0 10; OUT=$(run_status)
assert_has "$AMBER" "$OUT" "70% → amber (past 60)"; teardown

setup; add_rec x 0 170000 0 10; OUT=$(run_status)
assert_has "$ALERT" "$OUT" "85% → red (past 80)"; teardown

# ── 7. over-limit clamps rather than overflowing the bar ───────────────────
# Context can exceed the nominal window. An unclamped bar would print 13 blocks
# and wrap the statusline.
setup
add_rec x 0 400000 0 10
OUT=$(run_status)
assert_has "100%" "$OUT" "ctx above the limit clamps to 100%"
assert_not "███████████" "$OUT" "  bar stays 10 cells wide (no overflow)"
teardown

# ── 8. millions render as M, not as a six-digit k ──────────────────────────
setup
add_rec x 0 0 0 200000
OUT=$(run_status)
assert_has "burn 1.0M" "$OUT" "burn ≥1M humanises to M"
teardown

# ── 9. a truncated final line must not lose the whole transcript ──────────
# The transcript is appended to while this reads it, so the last line is
# routinely half-written. Aborting there would silently under-report every
# number on the statusline — false green in the instrument itself.
setup
add_rec x 0 100000 0 1000
printf '{"message": {"usage": {"input_到' >> "$TMP/transcript.jsonl"
OUT=$(run_status)
assert_has "50%" "$OUT" "truncated trailing line → earlier records still counted"
teardown

# ── 10. context label carries the repo and model for at-a-glance orientation ─
setup
add_rec x 0 100000 0 10
OUT=$(run_status)
assert_has "myrepo" "$OUT" "renders the workspace basename"
assert_has "Opus 5" "$OUT" "renders the model display name"
teardown

# ── report ───────────────────────────────────────────────────────────────────
printf '\n  %s────────────────────────────────────────%s\n' "$C_DIM" "$C_OFF"
if [ "$FAIL" -eq 0 ]; then
  printf '  %s▮ all %d checks read true%s\n\n' "$C_GOLD" "$PASS" "$C_OFF"
  exit 0
fi
printf '  %s✘ %d failed%s, %d passed\n' "$C_RED" "$FAIL" "$C_OFF" "$PASS"
for n in "${FAILED_NAMES[@]}"; do printf '      %s- %s%s\n' "$C_DIM" "$n" "$C_OFF"; done
printf '\n'
exit 1
