#!/bin/bash
# Executable tests for tools/check-drift.sh.
#
# Why these exist: this bundle's whole job is to put files in $HOME, and the
# deployed copies then rot independently of the repo. That already happened —
# home/CLAUDE.md sat 7h ahead of ~/.claude/CLAUDE.md after #3 and #7, so the
# live rules were missing a section describing two hooks that were installed
# and running, and still named skills EXCLUDED.md exists to record as removed.
# Nothing surfaced it, because a stale rules file loads, parses, and reads as
# authoritative exactly like a current one.
#
# The check was documented as four `diff` commands (#10). A command you have to
# remember to type is not a gate, so it became a script — and the script gets
# the same treatment as the hooks: every distinguishing case pinned here.
#
# The two cases that carry the most weight are the ones about NOT firing:
# the absolutized @import is an expected difference, and a check that cannot
# tell it from real drift would cry wolf on every correctly-installed machine.
# Its twin — a *different* edit on that same line — must still be caught.
#
# Isolation: each case builds a synthetic install root and points CHECK_ROOT at
# it. The real ~/.claude is never read and never written.
#
#   ./tests/test-drift.sh
#
set -u

BUNDLE="$(cd "$(dirname "$0")/.." && pwd)"
DRIFT="$BUNDLE/tools/check-drift.sh"
PASS=0
FAIL=0
FAILED_NAMES=()

# ── plumage ──────────────────────────────────────────────────────────────────
C_DIM=$'\033[38;2;85;85;85m'; C_GOLD=$'\033[38;2;240;192;64m'
C_RED=$'\033[38;2;220;80;80m'; C_OFF=$'\033[0m'

banner() {
  printf '%s\n' "  ${C_GOLD}⇄${C_OFF}   ${C_GOLD}drift${C_OFF} ${C_DIM}· deploy-parity regression flock${C_OFF}"
  printf '%s\n' " ${C_GOLD}⇄█⇄${C_OFF}  ${C_DIM}$DRIFT${C_OFF}"
  printf '%s\n\n' "  ${C_DIM}▀${C_OFF}"
}

ok()   { PASS=$((PASS+1)); printf '  %s✔%s %s\n' "$C_GOLD" "$C_OFF" "$1"; }
bad()  { FAIL=$((FAIL+1)); FAILED_NAMES+=("$1")
         printf '  %s✘ %s%s\n' "$C_RED" "$1" "$C_OFF"
         printf '    %sexpected:%s %s\n' "$C_DIM" "$C_OFF" "$2"
         printf '    %sgot:%s      %s\n' "$C_DIM" "$C_OFF" "${3:0:400}"; }

# ── fixtures ─────────────────────────────────────────────────────────────────
# A synthetic install root, populated from the real bundle. Cases then perturb
# one file at a time — so every finding is traceable to exactly one edit.
setup() {
  TMP=$(mktemp -d)
  ROOT="$TMP/root"
  mkdir -p "$ROOT/.claude/hooks" "$ROOT/.claude/skills" "$ROOT/.config/ai-rules"
}

teardown() { [ -n "${TMP:-}" ] && rm -rf "$TMP"; }

install_all() {
  cp "$BUNDLE/home/CLAUDE.md"           "$ROOT/.claude/CLAUDE.md"
  cp "$BUNDLE/home/ai-rules/global.md"  "$ROOT/.config/ai-rules/global.md"
  cp "$BUNDLE"/home/hooks/*             "$ROOT/.claude/hooks/"
  cp -R "$BUNDLE/home/skills/visual-decisions" "$ROOT/.claude/skills/"
}

# Exit code is part of the contract: 0 clean, 1 drift, 2 abstention.
run_drift() { CHECK_ROOT="$ROOT" bash "$DRIFT" 2>&1; }
rc_of()     { CHECK_ROOT="$ROOT" bash "$DRIFT" >/dev/null 2>&1; printf '%s' "$?"; }

assert_has() { case "$2" in *"$1"*) ok "$3";; *) bad "$3" "output contains '$1'" "$2";; esac; }
assert_not() { case "$2" in *"$1"*) bad "$3" "output does NOT contain '$1'" "$2";; *) ok "$3";; esac; }
assert_rc()  { [ "$2" = "$1" ] && ok "$3" || bad "$3" "exit $1" "exit $2"; }

banner

# ── 1. a faithful install is clean ───────────────────────────────────────────
setup
install_all
OUT=$(run_drift); RC=$(rc_of)
assert_rc 0 "$RC" "faithful install → exit 0"
assert_has "in sync" "$OUT" "  says so in words, not just an exit code"
teardown

# ── 2. the check reports its own denominator ─────────────────────────────────
# A drift check that compared nothing and exited 0 is the exact false green
# this repo exists to catch. The count must be visible, and non-zero.
setup
install_all
OUT=$(run_drift)
assert_has "check(s)" "$OUT" "clean run → still names how many checks ran"
assert_not "0 check(s)" "$OUT" "  and the count is never zero on a real install"
teardown

# ── 3. THE EXPECTED DIFFERENCE: absolutized @import is not drift ─────────────
# INSTALL.md §1 tells the installer to swap `~` for an absolute path when the
# import fails to resolve. A check that flagged that would fire on every
# correctly-installed machine, and a check that fires always gets ignored.
setup
install_all
sed -i.bak "s|@~/.config/ai-rules/global.md|@/Users/someone/.config/ai-rules/global.md|" \
  "$ROOT/.claude/CLAUDE.md" && rm -f "$ROOT/.claude/CLAUDE.md.bak"
OUT=$(run_drift); RC=$(rc_of)
assert_rc 0 "$RC" "absolutized @import → still clean"
assert_not "CLAUDE.md" "$OUT" "  and is not named as a finding"
teardown

# ── 4. ...but line 6 is not a blanket exemption ──────────────────────────────
# The normalization must be surgical. Skipping the whole line would let a
# rewritten import — the one thing that silently unloads every shared rule —
# through unnoticed.
setup
install_all
sed -i.bak "s|@~/.config/ai-rules/global.md|@/nowhere/hijacked.md|" \
  "$ROOT/.claude/CLAUDE.md" && rm -f "$ROOT/.claude/CLAUDE.md.bak"
OUT=$(run_drift); RC=$(rc_of)
assert_rc 1 "$RC" "line 6 pointed elsewhere → caught"
assert_has "CLAUDE.md" "$OUT" "  finding names the file"
teardown

# ── 5. body drift in the rules file ──────────────────────────────────────────
# The #9 shape: deployed copy missing a section the bundle has.
setup
install_all
grep -v "Context instruments" "$ROOT/.claude/CLAUDE.md" > "$ROOT/tmp" \
  && mv "$ROOT/tmp" "$ROOT/.claude/CLAUDE.md"
assert_rc 1 "$(rc_of)" "deployed rules missing a section → caught"
teardown

# ── 6. the shared rules file ─────────────────────────────────────────────────
setup
install_all
printf '\nstray edit\n' >> "$ROOT/.config/ai-rules/global.md"
OUT=$(run_drift); RC=$(rc_of)
assert_rc 1 "$RC" "global.md drift → caught"
assert_has "global.md" "$OUT" "  finding names the file"
teardown

# ── 7. a stale deployed hook ─────────────────────────────────────────────────
# The failure mode with teeth: a hook that runs every session, several fixes
# behind the copy under test.
setup
install_all
printf '\n# stale\n' >> "$ROOT/.claude/hooks/clear-nudge.sh"
OUT=$(run_drift); RC=$(rc_of)
assert_rc 1 "$RC" "stale deployed hook → caught"
assert_has "clear-nudge.sh" "$OUT" "  finding names the hook"
teardown

# ── 8. machine-local files are not drift ─────────────────────────────────────
# rot-watch.json is this machine's watchlist (the repo ships only the example),
# and the npm cache is generated. Flagging either would make a correct install
# permanently red.
setup
install_all
printf '{"watch":[{"cli":"local-only"}]}' > "$ROOT/.claude/hooks/rot-watch.json"
printf '{"pkg":{"latest":"9.9.9"}}'        > "$ROOT/.claude/hooks/.rot-npm-cache.json"
OUT=$(run_drift); RC=$(rc_of)
assert_rc 0 "$RC" "machine-local watchlist + cache → still clean"
assert_not "rot-watch.json" "$OUT" "  watchlist never reported as drift"
teardown

# ── 9. a file that never arrived is a finding, not silence ───────────────────
# "Cannot verify" is a finding. A missing deployed file must never read the
# same as a matching one.
setup
install_all
rm "$ROOT/.claude/CLAUDE.md"
OUT=$(run_drift); RC=$(rc_of)
assert_rc 1 "$RC" "deployed rules file absent → caught"
assert_has "missing" "$OUT" "  and is described as missing, not as differing"
teardown

# ── 10. a hook that never got installed ──────────────────────────────────────
setup
install_all
rm "$ROOT/.claude/hooks/statusline-context.sh"
OUT=$(run_drift); RC=$(rc_of)
assert_rc 1 "$RC" "hook never installed → caught"
assert_has "statusline-context.sh" "$OUT" "  finding names the absent hook"
teardown

# ── 11. the skill directory ──────────────────────────────────────────────────
setup
install_all
printf '\nstray\n' >> "$ROOT/.claude/skills/visual-decisions/SKILL.md"
assert_rc 1 "$(rc_of)" "skill drift → caught"
teardown

# ── 12. ABSTENTION: nothing installed is not "clean" ─────────────────────────
# Zero comparisons is the zero denominator. It must be distinguishable from a
# passing run by exit code AND by wording — a fresh clone on a machine that
# never installed the bundle must not report parity it never checked.
setup
OUT=$(run_drift); RC=$(rc_of)
assert_rc 2 "$RC" "empty root → exit 2, distinct from both clean and drift"
assert_not "in sync" "$OUT" "  never claims sync it did not verify"
assert_has "nothing" "$OUT" "  says plainly that there was nothing to check"
teardown

# ── 13. a partial install still gets checked ─────────────────────────────────
# Something is installed, so this is not an abstention — the absent pieces are
# findings. Half an install reporting like no install would hide the gap.
setup
cp "$BUNDLE/home/ai-rules/global.md" "$ROOT/.config/ai-rules/global.md"
OUT=$(run_drift); RC=$(rc_of)
assert_rc 1 "$RC" "partial install → drift, not abstention"
assert_has "missing" "$OUT" "  names what never arrived"
teardown

# ── 14. an extra file in the deployed hooks directory ────────────────────────
# A hook removed from the bundle but still live on the machine keeps firing.
setup
install_all
printf '#!/bin/bash\necho ghost\n' > "$ROOT/.claude/hooks/retired-hook.sh"
OUT=$(run_drift); RC=$(rc_of)
assert_rc 1 "$RC" "orphaned deployed hook → caught"
assert_has "retired-hook.sh" "$OUT" "  finding names the orphan"
teardown

# ── 15. THE CONTRACT: the check is read-only ─────────────────────────────────
# It reports; it never repairs. A checker that quietly fixed what it found
# would destroy the evidence of how far behind the machine had drifted.
setup
install_all
printf '\nstray edit\n' >> "$ROOT/.config/ai-rules/global.md"
BEFORE=$(find "$ROOT" -type f -exec shasum {} \; | shasum)
run_drift >/dev/null 2>&1
AFTER=$(find "$ROOT" -type f -exec shasum {} \; | shasum)
[ "$BEFORE" = "$AFTER" ] && ok "drift found → root left byte-identical (read-only)" \
                         || bad "read-only contract" "root unchanged" "root was modified"
teardown

# ── 16. the bundle itself is never written to either ─────────────────────────
setup
install_all
BEFORE=$(find "$BUNDLE/home" -type f -exec shasum {} \; | shasum)
run_drift >/dev/null 2>&1
AFTER=$(find "$BUNDLE/home" -type f -exec shasum {} \; | shasum)
[ "$BEFORE" = "$AFTER" ] && ok "bundle source left byte-identical" \
                         || bad "bundle untouched" "home/ unchanged" "home/ was modified"
teardown

# ── 17. default target is $HOME when CHECK_ROOT is unset ─────────────────────
# The documented invocation takes no arguments. If the default silently pointed
# somewhere else, every hand-run of this check would be inspecting nothing.
setup
install_all
OUT=$(HOME="$ROOT" bash "$DRIFT" 2>&1)
case "$OUT" in *"in sync"*) ok "no CHECK_ROOT → falls back to \$HOME";; \
  *) bad "no CHECK_ROOT → falls back to \$HOME" "clean run against \$HOME" "$OUT";; esac
teardown

# ── tally ────────────────────────────────────────────────────────────────────
printf '\n'
if [ "$FAIL" -eq 0 ]; then
  printf '  %s⇄ all %d checks matched their source%s\n\n' "$C_GOLD" "$PASS" "$C_OFF"
  exit 0
fi
printf '  %s✘ %d of %d failed:%s\n' "$C_RED" "$FAIL" "$((PASS+FAIL))" "$C_OFF"
for n in "${FAILED_NAMES[@]}"; do printf '    %s- %s%s\n' "$C_DIM" "$n" "$C_OFF"; done
printf '\n'
exit 1
