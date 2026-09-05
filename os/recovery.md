---
type: recovery
created: 2026-08-29
updated: 2026-09-05
reviewed: 2026-09-05
status: draft
authority: canon
source: ai
---

# recovery

**Bottom line:** Git history is required protection for normal changes; an off-device primary and independent backup close different recovery gaps.

**When to read this:** Before setup, update, structural change, publication, device replacement, or restore work.

## Repository protection

| Repository | Local path | Primary | Primary commit | Mirror | Mirror commit | Status | Checked |
|---|---|---|---|---|---|---|---|

Each repository has one primary. Agents push only to it. A secondary Git service is an automatic downstream mirror of the primary and is verified only when it reaches the same commit.

Use:

- `verified`;
- `configured but unverified`;
- `incomplete; device loss not covered`;
- `owner declined`;
- `deferred`;
- `unavailable`.

GitHub is the normal guided primary for new owners. An existing suitable GitLab or other hosted primary may be preserved when the owner prefers it. Local-only Git is an incomplete recovery state, not a completed standard setup. Do not record credential-bearing URLs.

## Additional recovery layers

| Layer | Scope | Location | State | Last restore proof | Checked |
|---|---|---|---|---|---|
| Git working history | tracked files in each repository | repositories above | unverified |  |  |
| Off-device primary | committed repository content | providers above | unverified |  |  |
| Automatic Git mirror | second committed copy | providers above | unverified |  |  |
| Full-file backup | untracked, ignored, hidden, and non-repository content, including root entry files | confirm during setup | unverified |  |  |
| Credential recovery | access needed to restore services | approved credential manager | unverified |  |  |

A planned layer is not a working backup. A successful upload is not a restore test. Say exactly what is uncovered.

## Before a meaningful change

1. **Protect.** Inspect tracked, untracked, ignored, hidden, and external content without changing it.
2. Create and read back the approved commit in every affected repository.
3. Verify each private primary and enabled mirror has that commit.
4. Create a separate local recovery copy outside the working OS for anything Git does not cover.
5. For an update, give the updater a new root-backup folder outside both the private OS and public source. Confirm its receipt and root entry copies can be read before the updater writes anything.
6. Read back the recovery evidence and explain the exact restore route before mutation.

Read-only review is allowed before recovery is complete. Do not proceed to mutation until the complete current state has a usable recovery route. Keep a pre-update recovery copy until validation succeeds and the owner accepts the result. An unrelated old repository stays untouched and backed up while selected context is brought into a separate new installation.

## Restore order

1. Stop writes and identify the exact failed change.
2. Preserve the current failed state for inspection when safe.
3. Use the approved source's `setup/scripts/restore-vault.rb plan TARGET BACKUP` to verify the complete transaction and detect later work.
4. After approval, use its `apply` mode. It restores recorded paths and verifies the protected inventory without resetting Git history. If it refuses, preserve later work and review a specific recovery plan; never force or discard to pass. Restore other uncovered content only from its separately verified backup.
5. Recover service access through the credential manager, never from the vault.
6. Run `validate-starter-os.rb`.
7. Verify the primary and mirrors again before resuming work.

Never claim recovery is complete from a clean current folder alone.
