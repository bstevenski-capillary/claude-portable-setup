#!/bin/bash
# SessionStart rules-drift check.
#
# Answers one question: have my global working rules changed since this bundle
# was last reconciled against them? If yes, the bundle is quietly stale and a
# machine set up from it gets a rule set I no longer run.
#
# Born of a real 17-day divergence. The bundle and the live ~/.claude/CLAUDE.md
# were both edited on the same day, minutes apart, and then drifted: the live
# file gained a whole section the bundle never got, and the bundle carried a
# note claiming a rule still needed fixing that had already been fixed. Nothing
# detected either, because nothing was watching — and both files individually
# looked fine.
#
# WHY THIS IS NOT A DIFF. The two files are DELIBERATELY different documents:
# the live one names employer/client/internal tooling, the bundle is the
# de-identified half (see EXCLUDED.md). A content diff would therefore fire on
# every single session and be trained away within a day — the same failure mode
# the tooling-rot siren's "no config = silent" rule exists to avoid. So this
# compares each file against a RECORDED FINGERPRINT taken at the last
# reconciliation, and fires only when one of them has actually moved since.
#
# Denominator honesty (rule 2): a missing bundle or an unreadable baseline is
# reported as a finding, not skipped. "Cannot verify" is a finding. Only a
# genuinely-absent config exits silently, because that means it was never asked
# for.
#
# Config:   ~/.claude/hooks/claude-md-drift.json   (see the .example.json)
# Baseline: <bundle>/home/hooks/claude-md-baseline.json  (committed, so
#           `git log` on it is the reconciliation history)
set -u

CLAUDE_DIR="$HOME/.claude"
CONFIG="$CLAUDE_DIR/hooks/claude-md-drift.json"
LIVE="$CLAUDE_DIR/CLAUDE.md"

emit() {
  python3 - "$1" <<'EOF'
import json, sys
msg = sys.argv[1]
print(json.dumps({
    "systemMessage": msg,
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": (
            "RULES-DRIFT NOTICE: the portable working-setup bundle is out of sync with the "
            "global rules actually in force. Mention this to the user in your first message "
            "and offer to reconcile — a stale bundle silently ships the wrong rule set to "
            "the next machine.\n" + msg
        ),
    },
}))
EOF
}

# Never asked for → claim nothing, say nothing.
[ -f "$CONFIG" ] || exit 0

BUNDLE=$(python3 -c "
import json,sys
try:
    print(json.load(open('$CONFIG')).get('bundle','').strip())
except Exception:
    print('__PARSE_ERROR__')
" 2>/dev/null)

case "$BUNDLE" in
  __PARSE_ERROR__|"")
    emit "RULES-DRIFT — config unreadable or has no 'bundle' path.
  $CONFIG
  ZERO checks ran. Cannot-verify is a finding, not a skip."
    exit 0
    ;;
esac

BUNDLE="${BUNDLE/#\~/$HOME}"
BASELINE="$BUNDLE/home/hooks/claude-md-baseline.json"
BUNDLE_MD="$BUNDLE/home/CLAUDE.md"

if [ ! -d "$BUNDLE" ]; then
  emit "RULES-DRIFT — bundle checkout not found.
  Configured path: $BUNDLE
  ZERO checks ran, so the bundle's freshness is UNKNOWN, not fine."
  exit 0
fi

if [ ! -f "$BASELINE" ] || [ ! -f "$BUNDLE_MD" ]; then
  emit "RULES-DRIFT — bundle is missing the files this check needs.
  expected: $BASELINE
        and: $BUNDLE_MD
  ZERO checks ran."
  exit 0
fi

[ -f "$LIVE" ] || { emit "RULES-DRIFT — no global rules file at $LIVE to compare against."; exit 0; }

# sha256 of each side, now.
LIVE_NOW=$(shasum -a 256 "$LIVE" 2>/dev/null | cut -d' ' -f1)
BUNDLE_NOW=$(shasum -a 256 "$BUNDLE_MD" 2>/dev/null | cut -d' ' -f1)

READ=$(python3 - "$BASELINE" <<'EOF'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception as e:
    print("__PARSE_ERROR__%s" % e); sys.exit(0)
print("\t".join([
    d.get("source_sha256", ""), d.get("bundle_sha256", ""), d.get("reconciled", "unknown"),
]))
EOF
)

case "$READ" in
  __PARSE_ERROR__*)
    emit "RULES-DRIFT — baseline unreadable: ${READ#__PARSE_ERROR__}
  $BASELINE
  ZERO checks ran."
    exit 0
    ;;
esac

IFS=$'\t' read -r BASE_LIVE BASE_BUNDLE WHEN <<< "$READ"

if [ -z "$BASE_LIVE" ] || [ -z "$BASE_BUNDLE" ]; then
  emit "RULES-DRIFT — baseline exists but records no fingerprints.
  $BASELINE
  A baseline that compares nothing is an abstention, not a pass."
  exit 0
fi

FINDINGS=""
[ "$LIVE_NOW" != "$BASE_LIVE" ] && FINDINGS="$FINDINGS
  - the LIVE rules changed since the last reconciliation ($WHEN).
    The bundle may be missing generic craft the live file has gained.
    ~/.claude/CLAUDE.md  now ${LIVE_NOW:0:12}…  baseline ${BASE_LIVE:0:12}…"
[ "$BUNDLE_NOW" != "$BASE_BUNDLE" ] && FINDINGS="$FINDINGS
  - the BUNDLE changed since the last reconciliation ($WHEN), without the
    baseline being restamped. Either finish the reconciliation or restamp it.
    home/CLAUDE.md  now ${BUNDLE_NOW:0:12}…  baseline ${BASE_BUNDLE:0:12}…"

# Both sides match their fingerprints: reconciled, and the denominator is real.
[ -z "$FINDINGS" ] && exit 0

emit "RULES-DRIFT — the portable bundle is stale:$FINDINGS

  Reconcile: compare the two files, move across ONLY generic craft (no employer,
  client, repo, registry, or internal tooling — see EXCLUDED.md), then restamp
  $BUNDLE/home/hooks/claude-md-baseline.json with both new sha256 values."
exit 0
