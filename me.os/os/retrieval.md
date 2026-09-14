---
type: map
created: SETUP_DATE
updated: SETUP_DATE
reviewed: SETUP_DATE
status: living
authority: canon
source: ai
---

# Retrieval and records

[← Knowledge map](knowledge-map.md)

Source authority, note metadata, and preservation of historical records.

## Resolve conflicts

- Apply the owner's current direction first.
- Prefer current material over superseded material and follow `superseded_by`, then use the owning project's source hierarchy.
- Use an approved `spec` for implementation and `canon` for settled principles. `reference` and `exploratory` are supporting material; metadata labels alone do not establish approval.
- For the same fact and scope, prefer the newer supported account. `updated` and `created` establish chronology, not evidence; `reviewed` records a review, not a decision.
- For otherwise equal accounts of the owner's intent, prefer the owner’s own words.
- Surface unresolved material conflicts. Links aid navigation; they do not establish authority.

## Metadata

Active notes use YAML frontmatter. Agent entries and native skill packages use their own formats; vendor documentation retains its upstream schema.

```yaml
---
type: note
created: YYYY-MM-DD
updated: YYYY-MM-DD
reviewed: YYYY-MM-DD
status: draft
authority: reference
source: ai
---
```

| Field | Values or meaning |
|---|---|
| `type` | `note`, `map`, `identity`, `skill`, `spec`, `handoff`, `daily`, `weekly`, `monthly`, `journal`, `decision-log`, `history`, `status` |
| `status` | `living`, `draft`, `superseded`, `done`; `superseded` requires `superseded_by` |
| `authority` | `canon`, `spec`, `reference`, `exploratory` |
| `source` | Drafter: `owner` or `ai`. Approval does not change authorship. |
| `created` | Creation date |
| `updated` | Last substantive content or truth change |
| `reviewed` | Last currency or metadata review |
| Optional routing | `domain`, `applies_to`, `related` |

Use real dates. When status or authority is uncertain, use `draft` or `reference` and flag the uncertainty.

## Make relevance clear

When a routed note's title and surrounding map do not make its value clear, open with a brief purpose statement. Use the structure that fits the note. Active links must resolve.

## Preserve history

Decision logs hold confirmed durable decisions. Preserve the bodies of dated records, transcripts, session history, and decision logs. Add authorized entries or dated corrections rather than rewriting the past. Verified lifecycle markings may change. Current project handoffs may be maintained under project rules; dated session records remain history.

Historical links may remain broken inside preserved bodies. Deleted files remain recovery evidence in Git, not current instructions.

## Daily continuity

Memory updates are part of normal meaningful work under the owner’s setup request and these instructions. An explicit read-only request, request not to save, or narrower privacy instruction takes precedence. This grants no authority to send messages, publish, trade, change calendars/reminders, or make new decisions for the owner.

| Information | Home |
|---|---|
| What is true or actionable now | Owning project file, Wiki, or Life's Now |
| What we decided and why | Established project decision log; otherwise [shared personal and workspace decisions](../life/records/decisions.md) |
| What happened and where to resume | `life/records/daily/YYYY-MM-DD.md` |

Business decisions stay in their owning project, using its established record or current document if it has no decision log. Do not create a new log just to satisfy this rule.

- **Read:** When resuming work or planning, read the owning current document and today's daily note if present. Follow the most recent relevant earlier entry when continuity is missing; do not load the whole history. Consult decisions before reopening a settled direction. Current verified service state and the owner's current words outrank old notes.
- **Update Now:** When confirmed information changes the owner’s broader personal situation, priorities, availability, or constraints across projects, update the owning project first. Keep only the relevant summary and link in [Life’s Now](../life/now.md). Replace outdated statements, date the information, and label uncertainty. Routine progress belongs in daily notes; project details stay with their owner. Don’t infer a new priority from activity alone.
- **Write:** At a meaningful stopping point, record useful progress, confirmed facts or commitments, blockers, and where to resume. Skip routine tool activity, trivial exchanges, and unchanged status. Use one note per active day using the current date supplied by the agent’s environment; no idle-day filler or scheduled job is needed.
- **Keep it brief:** Append a dated/time-labelled section with a few useful bullets and links to the owning documents or decision. Keep business and sensitive details with their owner; the shared daily note gets only appropriate cross-project context. Notes do not replace reminders or calendar entries.
- **Preserve:** Read the destination immediately before writing, deduplicate against existing entries, preserve concurrent edits, and append corrections or resolutions instead of rewriting earlier entries. Verify the entry after saving. Record older discoveries in today's note with their actual event date; never imply they were captured earlier.
- **Create:** Use the metadata above with `type: daily`, `status: living`, `authority: reference`, and `source: ai`. Set real creation/update/review dates. Daily filenames are their index; do not add each one to a map.
- **Reconcile:** When asked for a cross-task review, use only tasks and records you can actually read. Fill supported gaps without inventing missing events. Ordinary tasks record their own work.

## Decisions and handoffs

Record a lasting direction when the owner confirms it, not every implementation choice or new fact. Use the owning project's established record, or [shared decisions](../life/records/decisions.md) for personal and workspace decisions. Include the decision, date, reason, source context, and any superseded decision; preserve the log's existing ordering. Update the owning current document too. Daily notes link to the decision rather than repeating its rationale.

A handoff references current project truth and captures the goal, completed and remaining work, essential files, decisions, risks, and next action. Maintain a current handoff under project rules; dated session bodies remain history. File placement is defined in the [vault map](vault-map.md#file-ownership).
