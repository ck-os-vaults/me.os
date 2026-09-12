---
type: skill
created: 2026-08-30
updated: 2026-09-12
reviewed: 2026-09-12
status: living
authority: canon
source: ai
---

# drift recovery

## purpose

Find and resolve a mismatch between the system's declared truth and its actual files, repositories, integrations, automations, or active work without silently choosing one copy.

## trigger

Use when two durable sources disagree, a map points to missing or moved material, local and remote Git states differ unexpectedly, an automation no longer matches its canonical skill, validation reports structural drift, or the owner asks which copy is current.

## steps

1. Name the exact claimed sources, paths, versions, dates, commit identities, and owners without changing them.
2. Rank authority through `../retrieval.md`, but do not use recency alone to overwrite a higher-authority or owner-authored source.
3. Separate harmless staleness from a real conflict:
   - stale map or pointer;
   - duplicate but identical copy;
   - competing edits;
   - missing source;
   - unverified external state;
   - repository or mirror divergence.
4. Preserve every unique version and verify recovery coverage.
5. Show the owner the smallest resolution:
   - update a pointer;
   - designate one canonical owner and link the rest;
   - merge reviewed differences;
   - restore reviewed source content through the update process;
   - preserve or adapt an owner customization in place;
   - retire a duplicate after approval;
   - leave unresolved with a named next check.
6. Wait for approval before structural edits, replacement, deletion, Git history changes, remote changes, or automation changes.
7. Make only the approved correction, run the owning validator, and verify Git and external state independently.
8. Report what now owns the truth, what changed, what was preserved, and what remains uncertain.

## boundaries

- Never use silent last-write-wins.
- Never treat an agent's memory, summary, or confidence as stronger than durable evidence.
- Never delete a conflicting version merely because it appears older.
- Never force repository parity by reset, rebase, history rewrite, or force-push.
- Never claim an external mirror, integration, or automation is repaired without read-back evidence.
