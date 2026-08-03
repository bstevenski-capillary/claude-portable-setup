#!/bin/bash
# Run every suite in this directory and report a HONEST denominator.
#
# The one thing this must never do is exit 0 having run nothing. A runner that
# globs for suites, matches zero files, and reports "all clean" is the precise
# false-green shape the hooks under test exist to catch — so the empty case is
# a hard failure here, not a quiet pass.
#
#   ./tests/run-all.sh
#
set -u

cd "$(dirname "$0")" || exit 1

C_DIM=$'\033[38;2;85;85;85m'; C_GOLD=$'\033[38;2;240;192;64m'
C_RED=$'\033[38;2;220;80;80m'; C_OFF=$'\033[0m'

SUITES=()
for f in test-*.sh; do
  [ -f "$f" ] && SUITES+=("$f")
done

if [ "${#SUITES[@]}" -eq 0 ]; then
  printf '%s✘ ZERO suites matched test-*.sh — that is an abstention, not a pass.%s\n' \
    "$C_RED" "$C_OFF"
  exit 1
fi

printf '%s╭─ running %d suite(s)%s\n\n' "$C_DIM" "${#SUITES[@]}" "$C_OFF"

FAILED=()
for s in "${SUITES[@]}"; do
  bash "$s" || FAILED+=("$s")
done

printf '%s╰─ %d suite(s) run%s\n' "$C_DIM" "${#SUITES[@]}" "$C_OFF"
if [ "${#FAILED[@]}" -eq 0 ]; then
  printf '   %s▲ every suite flew clean%s\n\n' "$C_GOLD" "$C_OFF"
  exit 0
fi
printf '   %s✘ %d suite(s) failed:%s\n' "$C_RED" "${#FAILED[@]}" "$C_OFF"
for s in "${FAILED[@]}"; do printf '     %s- %s%s\n' "$C_DIM" "$s" "$C_OFF"; done
printf '\n'
exit 1
