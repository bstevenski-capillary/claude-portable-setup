#!/bin/bash
# Statusline: live context usage + this session's weighted burn.
#
# Why this exists: context is re-read on EVERY turn, so cost scales with
# (context size x turns). With no instrument, a session quietly grows from a
# ~90k baseline to 260k+ and every trivial reply starts costing 26k weighted
# tokens before it thinks a word. The corner indicator is too passive to
# notice mid-task; this is in front of you on every turn.
#
# Reads the statusline JSON payload on stdin (transcript_path, model, ...) and
# derives context from the LAST usage record in the transcript — that is the
# real number the API billed, not an estimate.
set -u

INPUT=$(cat)

python3 - "$INPUT" <<'EOF'
import json, sys, os

try:
    payload = json.loads(sys.argv[1])
except Exception:
    print("ctx —"); sys.exit(0)

transcript = payload.get("transcript_path") or ""
model = ((payload.get("model") or {}).get("display_name")) or ""
cwd = os.path.basename((payload.get("workspace") or {}).get("current_dir", "") or "")

# Relative billing weights (Opus): output 5x, cache-write 1.25x, cache-read 0.1x.
W_OUT, W_CREATE, W_READ, W_IN = 5.0, 1.25, 0.1, 1.0

ctx = 0
weighted = 0.0
try:
    with open(transcript, errors="ignore") as fh:
        for line in fh:
            if '"usage"' not in line:
                continue
            try:
                rec = json.loads(line)
            except Exception:
                continue
            u = (rec.get("message") or {}).get("usage") or rec.get("usage")
            if not u:
                continue
            weighted += (u.get("output_tokens", 0) * W_OUT
                         + u.get("cache_creation_input_tokens", 0) * W_CREATE
                         + u.get("cache_read_input_tokens", 0) * W_READ
                         + u.get("input_tokens", 0) * W_IN)
            # Context = everything the model saw on that request. The last
            # non-sidechain record is the live main-thread context.
            if not rec.get("isSidechain"):
                ctx = (u.get("input_tokens", 0)
                       + u.get("cache_read_input_tokens", 0)
                       + u.get("cache_creation_input_tokens", 0))
except Exception:
    pass

LIMIT = 200_000
pct = min(ctx / LIMIT, 1.0) if ctx else 0.0
filled = int(pct * 10)
bar = "█" * filled + "░" * (10 - filled)

# green under half, amber past 60%, red past 80% — the colour IS the nudge.
if pct >= 0.80:
    col = "\033[38;2;220;80;80m"
elif pct >= 0.60:
    col = "\033[38;2;240;192;64m"
else:
    col = "\033[38;2;120;180;120m"
dim, off = "\033[38;2;110;110;110m", "\033[0m"


def human(n):
    if n >= 1_000_000:
        return f"{n/1_000_000:.1f}M"
    if n >= 1_000:
        return f"{n/1_000:.0f}k"
    return str(int(n))


parts = []
if cwd:
    parts.append(f"{dim}{cwd}{off}")
parts.append(f"{col}{bar} {pct*100:.0f}%{off} {dim}{human(ctx)}{off}")
parts.append(f"{dim}burn {human(weighted)}{off}")
if model:
    parts.append(f"{dim}{model}{off}")
print(f" {dim}·{off} ".join(parts))
EOF
