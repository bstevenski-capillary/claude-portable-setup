---
name: visual-learner
description: "Brianna is a visual learner — render a visual display (mock, diagram, comparison card, blast-radius view) before asking her to make any non-trivial decision"
metadata: 
  node_type: memory
  type: user
  modified: 2026-07-22T20:04:58.328Z
---

Brianna is a visual learner and misses key implications when planning/brainstorming decisions are presented as prose-only option lists. This applies to ALL decisions, not just UI ones — for abstract choices the *consequences* (blast radius, UX impact, effort, risk) are what to visualize.

**Why:** She said so directly (2026-07-22) and asked for a durable workflow change, then explicitly broadened it to non-UI decisions. This prompted the `visual-decisions` personal skill and CLAUDE.md Working Rule 1.

**How to apply:** Before asking her to decide anything non-trivial: UI/structural → labeled wireframe mock or diagram; abstract choice → comparison cards / trade-off matrix with visual scales; refactor/scope → blast-radius diagram; end-user-affecting → before/after UX panel. Use AskUserQuestion option previews, the visualize widget, or an artifact. Visual first, then the question. Also applies to explanations: any multi-step or structural explanation (layering, lifecycles, upgrade paths, ripple effects, 3+ steps or 2+ interacting parts) gets a flow diagram alongside the prose.

**Level dial (her explicit constraint, 2026-07-22):** she will abandon the system if visuals add waiting or burn tokens fast — latency frustrates her more than anything. Default level `standard`: previews + plain-chat visuals (markdown tables with ●●○ scales, ASCII sketches) for most decisions; rendered widgets only for high-stakes structural calls. She switches with "visuals: quick" / "go rich". Never block a small question on a render. See `~/.claude/skills/visual-decisions/SKILL.md`.
