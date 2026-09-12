---
type: map
created: 2026-08-29
updated: 2026-09-12
reviewed: 2026-09-12
status: living
authority: canon
source: ai
---

# retrieval

## Retrieve

1. Start with the owning repository's `knowledge-map.md` or project home file.
2. Narrow by descriptive filename and opening summary.
3. Use full-text search for gaps and load only what the task needs.

## Rank conflicts

1. The owner's words in the current session.
2. Current material over superseded material.
3. The owning repository's declared source hierarchy.
4. Newer `updated` date, falling back to `created`.
5. Owner-authored intent over agent-drafted interpretation.

## Metadata

Use YAML metadata on routed knowledge where ranking or lifecycle matters:

```yaml
---
type: note
created: YYYY-MM-DD
updated: YYYY-MM-DD
reviewed: YYYY-MM-DD
status: living
authority: reference
source: owner
---
```

Use `status: living`, `draft`, `superseded`, or `done`; `authority: canon`, `spec`, `reference`, or `exploratory`; and `source: owner`, `ai`, or `starter-os`. `starter-os` records source origin, not an edit restriction. Preserve attribution when customizing and describe material adaptation honestly. A superseded file names its replacement.

Routed knowledge should open with a short **Bottom line:** and **When to read this:**. Historical records remain history and never outrank current truth.
