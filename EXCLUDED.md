# What was left behind, and why

This bundle is going to a **personal machine and a personal account**. That
boundary drove most of the cuts below — not size. Everything excluded here still
lives on the source machine; nothing was deleted.

## Employer / client material — not portable to a personal account

| Left behind | Why |
|---|---|
| `capwell-proposal` skill (+ CSS, banner and mockup assets) | Internal product-proposal workflow, internal Confluence conventions, company brand kit |
| `coe-client-onboarding` skill | Names specific client accounts and an internal platform |
| `commands/capillary/*` — api-coverage, neo, phi, test-reports, ui, vulcan | Company tooling; several wrap internal services that don't exist off the corporate network |
| `commands/harness/*` (~50 commands) and `agents/harness-*.md` (15 agents) | Installed from a private org marketplace; needs an SSO-authorized token to resolve. Won't install on a personal account. |
| `canary@bop-clocktower` plugin + its two siren hooks | Private marketplace, private repo, company test tooling |
| Company/client references throughout the global `CLAUDE.md` | Reference-implementation repos, client names, private package registries, internal ticket conventions |

The *patterns* from several of these did survive, stripped of anything
identifying:

- The canary session siren → `hooks/tooling-rot-siren.sh`, generalized to any
  plugin/CLI pair and config-driven.
- The harness/canary skill-priority table → rule 8, restated as "size a skill by
  its blast radius" rather than a list of internal skill names.
- The four-gate check, worktree isolation, and never-`--no-verify` conventions →
  kept verbatim; they're generic engineering practice.

## The permission allowlist — excluded, and worth cleaning up at the source

`permissions.allow` in the source `settings.json` holds ~90 entries, and most of
them are not permission rules at all. A pasted JSON payload was accepted
line-by-line into the allowlist, leaving entries like:

```
"Bash(\"<field>\": false,)"
"Bash(\"name\": \"<category value>\")"
"Bash(\"icon\": \"https://cdn.<vendor>.io/images/<project>/<asset>.png\",)"
```

(Redacted above — the real entries carry the literal values.)

Two problems, both worth acting on independently of this bundle:

1. **It carries client UAT payload data** — CDN asset URLs, record UUIDs, and
   domain category values from a client's test environment — sitting in a config
   file. Not regulated data, but client data in a place nobody would think to
   look for it, and easy to paste onward without noticing.
2. **The real rules are buried.** Roughly a dozen genuine entries
   (`Bash(npm run:*)`, `Bash(gh pr:*)`, `Bash(git -C:*)`, the harness ones) are
   lost among the noise, and the junk entries can never match anything.

So the template ships with `permissions.allow: []` on purpose. An allowlist
should grow from real prompts on the machine it protects; inheriting one imports
both another machine's blast radius and, here, its client data.

`additionalDirectories` was dropped for the same reason — it points at
work-repo paths that don't exist on the target machine.

## Skill overrides — trimmed, not copied

The source machine turns off ~30 skills. Nearly all of those `off` entries name
internal skills that won't exist on the target, so copying the list wholesale
would leave dead keys. Only `frontend-design` carried over. Repopulate this from
what actually proves noisy in practice.

## Note on one rule that changed in transit — now resolved

The source `CLAUDE.md` stated "distrust green until vetted" as a blanket hard
rule. That was a directive written during a specific remediation, and the tooling
it was aimed at has since been fixed. It was rescoped in this bundle (rule 2) to
the part that stays true regardless: a zero denominator is an abstention, and
"cannot verify" is a finding.

**Resolved on the source machine too.** Its `CLAUDE.md` now carries the rescoped
wording, so the two agree on this rule. (The source file is 17 minutes newer than
this bundle, which is why the note above read as outstanding for a while after it
had actually been fixed.)

## Second pass — generic craft that came over later

A later review compared the two files again and moved three things across. All
are generic; none names an employer, client, repo, registry, or internal tool.

| Added | Was excluded because | Kept how |
|---|---|---|
| Rule 9 — prefer first-party skills | The original was a table of internal skill names | Restated as a routing *habit*; the name mapping stays in private config |
| Rule 10 — issue tracker is the status source of truth, and fetch cadence | Original named internal repos and ticket conventions | Restated without them; the fetch-often reasoning is generic to fast-moving teams |
| Private registries & secrets (Repo Conventions) | Original named a private package scope and a specific password manager | Restated as "a scoped read token" and "a password manager" |

Note that rule 9 is deliberately *not* the same as rule 8. The first pass folded
the internal skill-priority table into rule 8 ("size a skill by blast radius"),
but those answer different questions — rule 8 is where a skill I write should
live, rule 9 is which existing skill to invoke. Only the latter was actually
missing.

## Still not portable

Everything in the tables above the line stays excluded, for the reasons given.
Re-adding any of it would break this bundle's one invariant: it installs on a
personal machine under a personal account, and references nothing that needs a
corporate network or an SSO-authorized token to resolve.
