---
name: visual-decisions
description: Render a visual display before asking the user to make ANY decision — during planning, brainstorming, architecture, or design discussions. UI/structural options get wireframe mocks or diagrams; abstract options (library choice, approach A vs B, config, scope) get comparison cards, trade-off matrices, or blast-radius diagrams. The user is a visual learner; a decision presented as prose-only risks being misunderstood.
---

# Visual Decisions

Brianna is a visual learner. Text-only option lists during planning/brainstorming cause her to
miss key implications. **Every decision point gets a visual display first — she chooses from the
picture, not the paragraph.** This applies even when the decision has no UI component: the
*consequences* of the choice (blast radius, UX impact, effort, risk) are the thing to visualize.

## When this applies

- Planning, brainstorming, or architecture sessions — including inside any planning/brainstorming
  skill. This skill layers on top of those; it does not replace them.
- **Any decision presented to her**, mapped to the right visual form:

| Decision type | Visual form |
|---|---|
| UI/UX (layouts, forms, dashboards, navigation) | Wireframe mock per option, side by side |
| Flows, architecture, pipelines, schemas | Mermaid/SVG diagram per option |
| Abstract choice (library, approach A/B, config, pattern) | Comparison cards or trade-off matrix — one card per option with impact/effort/risk shown as visual scales, not sentences |
| Scope or refactor decisions | Blast-radius diagram: what's touched, what's downstream, what stays untouched |
| Anything affecting end-user experience | Before/after panel of the UX consequence, even if the code change itself is invisible (API latency, error behavior, pagination, etc.) |

The only prose-only questions allowed are trivial one-liners with no meaningful consequences
(e.g. "commit message wording?"). If the options differ in blast radius, UX, effort, or risk —
that difference gets drawn.

## Explanations too, not just decisions

When *explaining* something multi-step or structural — how layers interact, a lifecycle, an
upgrade path, why a change ripples where it does, how a pipeline flows — pair the explanation
with a **flow diagram** (SVG/Mermaid via `show_widget`, `diagram` module). The prose carries the
why; the diagram carries the shape. If an explanation has 3+ steps or 2+ interacting parts, it
gets a diagram.

## Visual level — the frustration/spend dial

Brianna's explicit constraint (2026-07-22): visuals must not slow the session down or burn
tokens faster. **Latency is the enemy, not just cost** — if she has to pause and wait for a
render on every small question, she'll abandon the whole system. So render depth is leveled:

| Level | What renders | Latency / cost |
|---|---|---|
| **quick** | `AskUserQuestion` previews + plain-chat visuals only (markdown tables, ASCII wireframes, box sketches). Never load the widget tool. | Instant, near-zero tokens |
| **standard** *(default)* | Previews and plain-chat visuals for most decisions; an inline widget **only** for high-stakes structural calls (architecture, multi-service blast radius, UI layout she'll live with). Max ~1 widget per decision. | Occasional short render |
| **rich** | Full treatment — widgets liberally, artifacts for mocks worth revisiting, diagrams with explanations. | For design-heavy sessions |

- **Default is `standard`.** She can switch any time by saying e.g. "visuals: quick" / "go rich" —
  honor it for the rest of the session.
- **Auto-escalate, never auto-linger:** a genuinely high-stakes decision may step up one level;
  routine questions never do. When in doubt, render cheaper — a markdown comparison table she
  reads instantly beats a beautiful widget she waited for.
- **Never block a small question on a render.** If the visual isn't worth a pause, use a preview
  or plain-chat sketch.

## How to render — pick by decision size (within the active level)

| Situation | Tool | Notes |
|---|---|---|
| 2–4 discrete options, quick pick | `AskUserQuestion` with a `preview` on **every** option | The preview renders when the option is focused — put a compact wireframe/comparison card/diagram snippet in each so she compares visually while choosing. |
| Simple comparison or sketch, any level | Plain chat markdown — comparison table with visual scales (●●○), ASCII wireframe/flow | Zero latency; the workhorse at `quick` and `standard`. |
| One proposal to react to, or side-by-side comparison inline in chat (`standard`+ only) | `mcp__visualize__show_widget` (load `read_me` with the relevant module first, silently — `mockup` for UI, `diagram` for flows/blast radius) | Flat, compact, wireframe-fidelity. Label options A/B/… directly on the visual. |
| Rich/interactive mock, multi-screen flow, something to revisit later (`rich` only) | `Artifact` (load `artifact-design` skill first) | Use for full-page mockups or clickable flows; keep the same URL when iterating. |

## Rules for the visuals

1. **Wireframe fidelity, not pixel-perfect.** Grayscale boxes + labels beats polished styling —
   the goal is comparing structure and consequences, not admiring CSS. Exception: if the decision
   IS about visual style/branding, use whatever brand kit the project defines.
2. **Label everything on the visual** (Option A / Option B, region names, flow steps, affected
   modules) so the follow-up question can reference the labels directly.
3. **Annotate trade-offs on or beside the visual** — one short line per option, and show
   magnitude visually where possible (filled dots for effort/risk, colored badges for blast
   radius). The key differences she'd otherwise miss in prose should be *visible*.
4. **Visual first, then the question.** Render the display, then ask the decision question
   referencing it. Never ask first and offer a visual "if needed".
5. **Iterate on the same visual** when she counter-proposes — update it rather than describing
   the change in words.
