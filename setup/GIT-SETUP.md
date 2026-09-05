# Protection, authority, and recovery

> **Audience: Agent only.** Shared reference for installation and update. Explain outcomes in ordinary language; the owner need not learn Git commands.

## Discover before changing

Inspect approved repository roots, branches, worktrees, remotes, provider roles, private visibility, history, Git operations, and uncommitted work. Redact credential-bearing URLs. Inventory relevant tracked, untracked, ignored, hidden, root-level, and external content. Existing provider names are not proof of primary status or working protection.

The standard topology is independent `os/`, `life/`, and each real `biz/<business>/`. The vault root and empty `biz/` container remain plain. Preserve other topology and all unique history; obtain an exact protected conversion plan before using tools that require these boundaries. Do not reset, stash, switch branches, rewrite history, change remotes, or merge divergence merely to pass a check.

## Recommend protection early; respect choice

GitHub is the normal guided private primary when no suitable hosted primary exists. Preserve another suitable private host when preferred. Explain that local history helps recover bad edits and a verified hosted copy protects against device loss. A mirror is a further optional layer, not required onboarding work.

After the setup plan is approved, guide account security and verify the approved private repository destinations before substantial personalization. The owner handles sign-in, multifactor authentication, recovery codes, and secrets privately. Use only approved credential access; never request secret values in chat.

If GitHub is declined, offer an existing host or local Git. If all Git is declined or deferred, a new foundation in an empty location may proceed under that explicit choice. Offer an approved file-backup option and state the remaining limitation once. Do not repeatedly ask, create Git anyway, or call the result fully protected. Record `owner declined`, `deferred`, or `incomplete; device loss not covered` accurately. An update still requires usable recovery; an earlier opt-out does not authorize risking existing work.

## One primary and optional mirrors

Each repository has one primary. Agents push only to it, within publication authority. A secondary service is an automatic downstream mirror configured from the primary using an approved mechanism. Do not keep a second routine agent push target. Verify the expected commit on both services before declaring parity. If mirroring cannot be verified, record the exact gap without silently reverting to dual pushes.

Create and read back the first local commit as soon as the new scaffold exists; verify the private hosted copy before substantial personalization when protection is accepted. Review visibility and privacy before every first private push. Do not use a public fork as the owner's working system. Finish a real business with its own readable commit, private hosted primary, and recovery record.

## One concrete authority boundary

The shared plan names exact locations, repository/account actions, privacy, recovery, material changes, and any cleanup. Approval continues for those unchanged actions. Ask again only for new scope or genuine choices. A request to inspect an update is not permission to apply it. Structural changes, deletion, messages, publication, spending, access changes, and scheduled work need clear authority. Silence is not approval.

## Protect an existing system

Before update writes:

1. Verify readable recovery commits in the affected independent repositories; stop for divergence, unfinished operations, or unprotected current work.
2. Verify the private hosted primaries and enabled mirrors at the intended recovery commits, or report unresolved standard-protection requirements before proceeding.
3. Make a readable local recovery copy outside the working OS for relevant files Git does not cover. Explicitly scope external files and preserve them separately; the updater does not copy external targets through links.
4. Give update apply a new external `--root-backup` directory, outside both source and target. It becomes the transaction backup, including root entries, before/after bytes for every write, original repository commits, and a complete local inventory excluding Git internals.
5. Keep all recovery material until validation succeeds and the owner accepts the result. A receipt is recovery data, not a second operational home.

The updater stages and reads back all write bytes and recovery evidence before changing the target. Writes are atomic per file; the entire multi-repository update is not one atomic operation. On interruption, preserve the receipt and use the restore guide in `UPDATE.md`. It refuses to discard later owner changes. Restoration never resets Git history or changes remote services.

## Record truthful evidence

Use owner-owned `os/recovery.md` for each repository's location, primary, expected commit, optional mirror, verification date/state, full-file backup, and last restore proof. Use `verified`, `configured but unverified`, `incomplete; device loss not covered`, `owner declined`, `deferred`, or `unavailable`. A planned backup or successful upload is not a restore test. Local validation does not contact a host, scheduler, or backup service.

## Source cleanup after success

The installed system never keeps the public `setup/` folder. Future updates begin from a fresh approved source.

- Remote-only source: no local cleanup.
- Temporary checkout/download: remove the exact approved copy only after proving it contains no owner files, secrets, unique commits, or uncommitted work.
- Intentional maintainer checkout or uncertain pre-existing folder: retain it and state why.

Never delete individual setup files, the recovery copy, or the owner's old repository as installer cleanup. Record cleanup as complete, intentionally retained, not applicable, or unresolved.
