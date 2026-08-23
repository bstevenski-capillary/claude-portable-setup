#!/bin/bash
# Executable tests for tools/bare-install.sh.
#
# Why these exist: the repo's success test is "a stranger clones it and it works
# on their machine" (STRATEGY.md). Nothing proved that. Every existing suite
# runs against a synthetic root that the *test* populated, so all four suites
# would still pass on a bundle whose install spec had quietly stopped working —
# they exercise the artifacts, never the act of installing them.
#
# The trap this suite exists to spring is SC-3. `tools/check-drift.sh` spends a
# whole exit code on "nothing of the bundle was installed at this root, so
# nothing was compared" — exit 2, an abstention. A bare-install job that shelled
# out to the drift check and accepted any non-1 status would therefore go green
# on an install that copied *zero files*, and it would look exactly like a real
# pass. That is this repo's founding bug in a new costume, so it is pinned here
# before the tool it describes exists.
#
# The contract, in four parts:
#   1. A fresh scratch root installs clean and exits 0.
#   2. The run states its own denominator, and the denominator is never zero.
#   3. A drift check that abstains (exit 2) fails the install, exit 1, and the
#      output says the word "abstention" — a red that does not say which red it
#      was sends the reader to the wrong place.
#   4. The success path leaves no scratch state behind.
#
# Isolation: the tool creates its own scratch root under $TMPDIR and prints it.
# The real ~/.claude is never read and never written. Case 3 runs against a
# *copy* of the bundle with a stubbed drift check, so the production script
# needs no test-only seam — BUNDLE derives from `dirname "$0"`, so pointing the
# script at a copy of itself is the whole fixture.
#
#   ./tests/test-bare-install.sh
#
set -u

BUNDLE="$(cd "$(dirname "$0")/.." && pwd)"
BARE="$BUNDLE/tools/bare-install.sh"
PASS=0
FAIL=0
FAILED_NAMES=()

# ── plumage ──────────────────────────────────────────────────────────────────
C_DIM=$'\033[38;2;85;85;85m'; C_GOLD=$'\033[38;2;240;192;64m'
C_RED=$'\033[38;2;220;80;80m'; C_OFF=$'\033[0m'

banner() {
  printf '%s\n' "  ${C_GOLD}⇱${C_OFF}   ${C_GOLD}bare-install${C_OFF} ${C_DIM}· the stranger's first flight${C_OFF}"
  printf '%s\n' " ${C_GOLD}⇱█⇱${C_OFF}  ${C_DIM}$BARE${C_OFF}"
  printf '%s\n\n' "  ${C_DIM}▀${C_OFF}"
}

ok()   { PASS=$((PASS+1)); printf '  %s✔%s %s\n' "$C_GOLD" "$C_OFF" "$1"; }
bad()  { FAIL=$((FAIL+1)); FAILED_NAMES+=("$1")
         printf '  %s✘ %s%s\n' "$C_RED" "$1" "$C_OFF"
         printf '    %sexpected:%s %s\n' "$C_DIM" "$C_OFF" "$2"
         printf '    %sgot:%s      %s\n' "$C_DIM" "$C_OFF" "${3:0:400}"; }

assert_has() { case "$2" in *"$1"*) ok "$3";; *) bad "$3" "output contains '$1'" "$2";; esac; }
assert_not() { case "$2" in *"$1"*) bad "$3" "output does NOT contain '$1'" "$2";; *) ok "$3";; esac; }
assert_rc()  { [ "$2" = "$1" ] && ok "$3" || bad "$3" "exit $1" "exit $2"; }

# Exit code is part of the contract: 0 installed and verified, 1 anything else.
run_bare() { bash "$1" 2>&1; }
rc_of()    { bash "$1" >/dev/null 2>&1; printf '%s' "$?"; }

# The tool prints the scratch root it used, so case 4 can assert its removal
# without the suite having to dictate the path — a script that deleted a
# caller-supplied directory would be a worse tool for a slightly easier test.
root_from() { printf '%s' "$1" | sed -n 's/.*scratch root: \([^ ]*\).*/\1/p' | head -1; }

tally() {
  printf '\n'
  if [ "$FAIL" -eq 0 ]; then
    printf '  %s⇱ all %d checks cleared the nest%s\n\n' "$C_GOLD" "$PASS" "$C_OFF"
    exit 0
  fi
  printf '  %s✘ %d of %d failed:%s\n' "$C_RED" "$FAIL" "$((PASS+FAIL))" "$C_OFF"
  for n in "${FAILED_NAMES[@]}"; do printf '    %s- %s%s\n' "$C_DIM" "$n" "$C_OFF"; done
  printf '\n'
  exit 1
}

banner

# ── 0. the tool exists at all ────────────────────────────────────────────────
# Stated as its own case so the RED run names the missing file instead of
# reporting four cascading exit-127s that describe nothing.
if [ ! -f "$BARE" ]; then
  bad "tools/bare-install.sh exists and is executable" \
      "a file at $BARE" \
      "absent — Task 5 has not been implemented yet"
  tally
fi
[ -x "$BARE" ] && ok "tools/bare-install.sh exists and is executable" \
                || bad "tools/bare-install.sh exists and is executable" \
                       "the exec bit set" "present but not executable"

# ── 1. a bare root installs clean ────────────────────────────────────────────
# The whole point: no overlay, no prior ~/.claude, nothing of the author's.
# STRATEGY.md's core layer contract says the core must be fully functional with
# every overlay absent, and this is the case that makes that falsifiable.
OUT=$(run_bare "$BARE"); RC=$(rc_of "$BARE")
assert_rc 0 "$RC" "bare scratch root → exit 0"
assert_not "abstention" "$OUT" "  and does not quietly report an abstention as success"

# ── 2. the run names its own denominator ─────────────────────────────────────
# Inherited verbatim from test-drift.sh case 2, because the failure mode is
# identical: a run that verified nothing and exited 0 is indistinguishable from
# a run that verified everything, unless the count is on screen.
assert_has "check(s)" "$OUT" "install run → names how many checks ran"
assert_not "0 check(s)" "$OUT" "  and the count is never zero"

# ── 3. SC-3: an abstaining drift check is a FAILURE, not a pass ──────────────
# The load-bearing case. A stubbed check-drift.sh that prints nothing and exits
# 2 stands in for the real failure this guards: an install that placed no files,
# leaving the drift check with nothing to compare. Accepting that as green would
# certify a bundle that installs nothing at all.
FAKE=$(mktemp -d)
cp -R "$BUNDLE/." "$FAKE/fakebundle" 2>/dev/null
printf '#!/bin/bash\nexit 2\n' > "$FAKE/fakebundle/tools/check-drift.sh"
chmod +x "$FAKE/fakebundle/tools/check-drift.sh"
OUT3=$(run_bare "$FAKE/fakebundle/tools/bare-install.sh"); RC3=$(rc_of "$FAKE/fakebundle/tools/bare-install.sh")
assert_rc 1 "$RC3" "drift check exits 2 → install fails"
assert_has "abstention" "$OUT3" "  and the failure says which failure it was"
rm -rf "$FAKE"

# ── 4. the success path leaves no scratch state behind ───────────────────────
# A tool that installs into $TMPDIR and never cleans up turns a CI matrix into a
# disk-usage bug, and turns a local run into a pile of half-installed roots that
# the next run might read.
SCRATCH=$(root_from "$OUT")
if [ -z "$SCRATCH" ]; then
  bad "success path names the scratch root it used" \
      "a line matching 'scratch root: <path>'" "$OUT"
else
  ok "success path names the scratch root it used"
  [ ! -d "$SCRATCH" ] && ok "  and removes it when the install succeeds" \
                      || bad "  and removes it when the install succeeds" \
                             "$SCRATCH gone" "$SCRATCH still present"
fi

tally
