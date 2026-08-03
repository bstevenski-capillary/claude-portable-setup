#!/bin/bash
# SessionStart tooling-rot siren.
#
# Yells about degraded local tooling BEFORE any work starts. Local-only checks
# (<1s, no network). On findings it injects a loud warning into session context
# AND shows the user a systemMessage.
#
# Born of an incident where a test toolchain ran silently broken for ~7 weeks
# while every surface reported green.
#
# Denominator honesty: if a watchlist EXISTS but covers nothing (empty or
# unparseable), that is reported — you intended coverage and have none. If no
# watchlist exists at all, this exits silently: you never asked it to watch
# anything, and a siren that fires every session is a siren that stops being
# read. See "check the denominator" in ~/.claude/CLAUDE.md.
#
# Config: ~/.claude/hooks/rot-watch.json   (see rot-watch.example.json)
set -u

CLAUDE_DIR="$HOME/.claude"
CONFIG="$CLAUDE_DIR/hooks/rot-watch.json"
FINDINGS=()
CHECKS_RUN=0

emit() {
  # emit <systemMessage-body>
  python3 - "$1" <<'EOF'
import json, sys
msg = sys.argv[1]
print(json.dumps({
    "systemMessage": msg,
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": (
            "HEADLINE ALERT (tooling-rot siren): local tooling is degraded or unverified. "
            "Per the 'distrust green until vetted' rule, surface this to the user in your "
            "FIRST message and treat it as outranking new work.\n" + msg
        ),
    },
}))
EOF
}

# ---------------------------------------------------------------- no config --
# Nothing was ever asked for, so nothing is claimed. Silent by design — the
# alternative is an alert on every session, which trains you to ignore it.
[ -f "$CONFIG" ] || exit 0

# ------------------------------------------------------------ read watchlist --
# Each watch entry may set any subset of:
#   plugin        plugin id, e.g. "mytool@my-marketplace"  (installed + enabled)
#   marketplace   marketplace dir name under plugins/marketplaces (git freshness)
#   cli           command name on PATH  (presence, and version vs plugin)
#   stale_days    freshness threshold for the marketplace checkout (default 14)
WATCH=$(python3 - "$CONFIG" <<'EOF'
import json, sys
try:
    cfg = json.load(open(sys.argv[1]))
except Exception as e:
    print("__PARSE_ERROR__%s" % e)
    sys.exit(0)
for w in cfg.get("watch", []):
    # \x1f (unit separator), NOT tab: tab is IFS whitespace, so bash's `read`
    # collapses runs of it and strips leading ones — which silently shifts every
    # field left whenever an entry omits a key. A non-whitespace delimiter makes
    # empty fields survive intact.
    print("\x1f".join([
        w.get("plugin", ""), w.get("marketplace", ""),
        w.get("cli", ""), str(w.get("stale_days", 14)),
    ]))
EOF
)

case "$WATCH" in
  __PARSE_ERROR__*)
    emit "TOOLING-ROT SIREN — config unreadable.
  $CONFIG failed to parse: ${WATCH#__PARSE_ERROR__}
  ZERO checks ran. Cannot-verify is a finding, not a skip."
    exit 0
    ;;
esac

if [ -z "$WATCH" ]; then
  # A config that exists but watches nothing is the case worth flagging:
  # coverage was intended and isn't there.
  emit "TOOLING-ROT SIREN — empty watchlist.
  $CONFIG parsed but lists nothing to watch, so ZERO checks ran.
  Either populate it or delete it (no config = intentionally silent)."
  exit 0
fi

# ----------------------------------------------------------------- the checks --
# Read on FD 3, not stdin: children spawned in the loop body inherit stdin and
# can consume it. Keeping the watchlist on its own descriptor makes the loop
# structurally immune to that, regardless of what a watched command does.
while IFS=$'\x1f' read -r -u 3 PLUGIN MKT_NAME CLI STALE_DAYS; do
  [ -z "$PLUGIN$MKT_NAME$CLI" ] && continue
  LABEL="${PLUGIN:-${CLI:-$MKT_NAME}}"
  MKT="$CLAUDE_DIR/plugins/marketplaces/$MKT_NAME"
  PLUGIN_VER="unknown"

  # 1. Plugin installed AND enabled. (A past failure: flat files bypassed the
  #    plugin system entirely, so nothing tracked versions at all.)
  if [ -n "$PLUGIN" ]; then
    CHECKS_RUN=$((CHECKS_RUN + 1))
    if ! grep -q "\"$PLUGIN\"" "$CLAUDE_DIR/plugins/installed_plugins.json" 2>/dev/null; then
      FINDINGS+=("$LABEL: plugin NOT installed (claude plugin install $PLUGIN)")
    elif ! python3 -c "
import json,sys
d=json.load(open('$CLAUDE_DIR/settings.json'))
sys.exit(0 if d.get('enabledPlugins',{}).get('$PLUGIN') else 1)" 2>/dev/null; then
      FINDINGS+=("$LABEL: plugin installed but NOT enabled in settings.json")
    fi
  fi

  # 2. Marketplace checkout freshness. A stale checkout drifts silently.
  if [ -n "$MKT_NAME" ]; then
    CHECKS_RUN=$((CHECKS_RUN + 1))
    if [ -d "$MKT/.git" ]; then
      LAST_FETCH="$MKT/.git/FETCH_HEAD"
      [ -f "$LAST_FETCH" ] || LAST_FETCH="$MKT/.git/HEAD"
      if [ -n "$(find "$LAST_FETCH" -mtime +"${STALE_DAYS:-14}" 2>/dev/null)" ]; then
        FINDINGS+=("$LABEL: marketplace checkout not refreshed in >${STALE_DAYS:-14} days (claude plugin marketplace update $MKT_NAME)")
      fi
      PLUGIN_VER=$(python3 -c "
import json;print(json.load(open('$MKT/.claude-plugin/plugin.json'))['version'])" 2>/dev/null || echo "unknown")
    else
      FINDINGS+=("$LABEL: marketplace checkout missing at $MKT")
    fi
  fi

  # 3. CLI presence, and CLI-vs-plugin version skew. The CLI and the plugin
  #    that drives it must move together or the plugin calls a stale surface.
  if [ -n "$CLI" ]; then
    CHECKS_RUN=$((CHECKS_RUN + 1))
    if command -v "$CLI" >/dev/null 2>&1; then
      # Strip ANSI: many CLIs print a decorated banner for --version.
      # </dev/null is mandatory: some watched "CLIs" are MCP stdio servers that
      # do not recognize --version and instead start up and read stdin to EOF.
      # Without this they drain the watchlist and every later entry is silently
      # skipped — a truncated denominator inside the denominator checker.
      CLI_VER=$("$CLI" --version 2>/dev/null </dev/null | sed $'s/\x1b\\[[0-9;]*m//g' \
        | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
      CLI_VER=${CLI_VER:-unknown}
      if [ "$PLUGIN_VER" != "unknown" ] && [ "$CLI_VER" != "unknown" ] \
         && [ "$CLI_VER" != "$PLUGIN_VER" ]; then
        FINDINGS+=("$LABEL: version skew — CLI $CLI_VER vs plugin $PLUGIN_VER; sync them")
      fi
    else
      FINDINGS+=("$LABEL: CLI '$CLI' not on PATH")
    fi
  fi
done 3<<< "$WATCH"

# --------------------------------------------------------------------- report --
if [ "${#FINDINGS[@]}" -eq 0 ]; then
  # Healthy AND non-empty denominator: this is the one case worth staying quiet for.
  exit 0
fi

LINES=""
for f in "${FINDINGS[@]}"; do LINES="$LINES
  - $f"; done
emit "TOOLING-ROT SIREN — ${#FINDINGS[@]} finding(s) across $CHECKS_RUN check(s):$LINES"
exit 0
