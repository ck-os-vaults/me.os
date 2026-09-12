---
type: skill
created: 2026-06-20
updated: 2026-09-12
reviewed: 2026-09-12
status: living
authority: canon
source: ai
---

# metadata audit

## purpose

Keep lifecycle, authority, provenance, summaries, and routes trustworthy so agents do not confidently use stale material.

## trigger

Run after imports/restructures, periodically, or when retrieval surfaces the wrong file.

## steps

1. Choose one repo or area.
2. Identify the owning files and task authority. All installed content belongs to the owner; source provenance is not an edit restriction. List metadata gaps and repair only within the approved audit scope.
3. Cross-check currency against current status, specs, decisions, and owner words.
4. Set `reviewed` to the audit date; change `updated` only when content/current truth changed.
5. Mark replaced current files `superseded` with `superseded_by`; leave dated history as history; use `draft` when uncertain.
6. Set authority and source honestly.
7. Ensure top summaries describe real contents and read triggers.
8. Update maps and indexes when lifecycle or location changed.
9. Run `ruby os/validate-starter-os.rb`; distinguish owner notices from failures and repair only authorized changes.
10. Report counts, conflicts, and owner decisions.

## boundaries

- Never delete by default.
- Do not invent dates, authority, approval, or currentness.
- Do not rewrite owner-authored body text during a metadata-only audit.
- Protected files require current owner permission.
