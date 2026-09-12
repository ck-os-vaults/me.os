---
type: map
created: 2026-08-29
updated: 2026-09-12
reviewed: 2026-09-12
status: living
authority: canon
source: ai
---

# skill map

**Bottom line:** Starter.OS includes reusable methods. A skill runs only when a real task calls for it. A schedule exists only after the owner accepts it.

**When to read this:** Read with owner-owned `owner-skills.md` when choosing, adding, updating, scheduling, or auditing a reusable workflow.

## Public skill audit

| Skill | Product role | Trigger | Scheduled recipe |
|---|---|---|---|
| [[git-sync-preflight]] | core portable | before substantive repository work | no |
| [[decision-log]] | core portable | owner confirms a durable decision | no |
| [[security-intake]] | core portable | before adopting or executing outside material; passive reading uses a light source check | no |
| [[security-sweep]] | core portable plus optional scheduled routine | sensitive or public work, explicit security review, or accepted security watch | System Security Watch |
| [[vault-maintenance]] | core portable | owner-approved structural or routing cleanup | no |
| [[drift-recovery]] | core portable | sources, copies, or routes conflict or drift | no |
| [[distill]] | optional portable | accumulated records contain durable signal worth promoting | no |
| [[metadata-audit]] | optional portable | routing or lifecycle metadata repeatedly drifts | no |
| [[browser-use]] | optional portable | interactive website work | no |
| [[daily-brief]] | optional scheduled routine | start-of-day or priority planning | Morning Brief |
| [[news-report]] | optional scheduled routine | owner wants a recurring report from selected sources | News Report |
| [[eod-wrap]] | optional scheduled routine | owner asks to wrap or adopts an end-of-day routine | optional owner-defined |
| [[task-reconciliation]] | optional portable | cross-project checkpoint or input to a Morning Brief | no separate report by default |

## Adapter and exclusion audit

- **Agent-specific pointers.** Root and repository `CLAUDE.md` files point to the shared rules. Scheduler-specific or agent-specific files may live outside the portable skill folder, but they must point back here.
- **CK-only or private.** None are included. Private methods stay outside the public repository.
- **Incomplete or unsupported.** None are included. A candidate stays outside the release until its trigger, limits, requirements, and checks are clear.

A file appearing in this map does not authorize execution, installation, connection, or scheduling.

## Creation contract

When a broadly reusable workflow is added or materially changed:

1. Keep the canonical intent in `os/skills/`.
2. For owner additions, register it in `owner-skills.md` with one role and a real trigger. Both registries belong to the owner; maintain existing entries when their workflow changes. A product update is not required.
3. Keep project-specific or owner-specific methods with their owner.
4. Add an agent-specific pointer only when discovery or tooling needs it.
5. Declare external tools, data exposure, permissions, cost, and a free or already-owned alternative.
6. Keep scheduled use opt-in and give it a clear destination and retirement path.
7. Run `ruby os/validate-starter-os.rb` and validate any adapter.

## Maintenance contract

Audit after a major agent, model, tool, repository, or product update:

1. Read both this map and `owner-skills.md`. Every skill has one registration and every registration resolves.
2. Every role and trigger still matches the real workflow.
3. Core skills remain model- and agent-agnostic.
4. Optional integrations remain optional and truthfully available.
5. Scheduled routines have explicit owner acceptance, compatible source access, a persistent destination when supported, and no duplicates.
6. Stale, private, unsupported, or provider-bound material is removed from the public release or reclassified after approval.
7. Instructions, lifecycle dates, maps, adapters, and validation change together.

Do not create an automation merely because a recipe exists.
