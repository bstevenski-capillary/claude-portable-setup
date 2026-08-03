---
name: shared-agent-rules-symlink
description: "Global working rules live in ~/.config/ai-rules/global.md, symlinked into Gemini/Codex/Copilot; ~/.claude/CLAUDE.md is a real file that @imports it and adds Claude-only mechanics"
metadata: 
  node_type: memory
  type: project
  modified: 2026-08-03T04:24:39.392Z
---

Agent rules are split in two on purpose (decided 2026-08-02):

- `~/.config/ai-rules/global.md` — agent-agnostic working rules. Symlinked from
  `~/.gemini/GEMINI.md`, `~/.gemini/AGENTS.md`, `~/.codex/AGENTS.md`, and
  `~/.config/github-copilot/instructions.md`.
- `~/.claude/CLAUDE.md` — a **real file** (the symlink was deliberately removed) that
  `@imports` the shared file and adds Claude-only mechanics: the
  [[visual-learner]] level dial, the tooling-rot siren hook, `~/.claude/skills/`
  scoping, and permission-allowlist hygiene.

**Why:** the shared file reaches four agents, so Claude-specific references
(skill paths, hooks, `permissions.allow`) would be dead text for three of them.
Splitting keeps each agent's rules true for that agent.

**How to apply:** edit shared/universal rules in `~/.config/ai-rules/global.md`;
edit Claude-only mechanics in `~/.claude/CLAUDE.md`. **Never `Write` to
`~/.claude/CLAUDE.md` expecting a symlink** — and conversely, if it is ever
re-symlinked, a write there silently overwrites the shared file for all four
agents. Check what the file actually is before writing to it.
