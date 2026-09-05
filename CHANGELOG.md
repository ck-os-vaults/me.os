# Changelog

All notable Starter.OS changes are recorded here.

Starter.OS follows semantic versioning. Major versions may change the operating contract or require extra owner review. Minor versions add compatible features. Patch versions fix behavior or documentation without changing the contract.

Changes being developed belong under **Unreleased**. When a release is approved, those entries move into a dated version section. Starter.OS history before 2.0.0 was unversioned.

## [Unreleased]

Starter.OS 3.1.0 is an unreleased candidate distributed on main for owner testing. It has not been tagged or formally released. An approved released source is the normal owner path; candidate writes require an explicit choice.

### Added

- Owner-directed full or selected improvement plans with explicit source and inventory checks. Selected adoption records its scope without advancing the base version to a fully adopted release.
- Owner-owned skill registry, preserving personal workflows without editing the managed product map.
- Complete external update transactions and a deterministic restore preview/apply workflow that protects later owner work.
- Explicit update support for the actual distributed 3.0 candidate, in addition to declared historical sources.
- Foundation-only validation for a new owner's explicit Git deferral, with accurate protection notices.

### Changed

- Setup lays a verified foundation and offers optional suggestions. A task, example project, exercise, or automation is never required.
- Private Git protection is recommended early; existing suitable hosts and explicit declines/deferrals are respected.
- The README is the owner entry. Setup now has three guides: installation, updates, and shared Git/recovery. Unique content and routes from the two retired guides are consolidated there.
- Personal planning, browser choice, and agent configuration follow the owner's actual preferences and capabilities.
- Validation distinguishes preserved owner layouts/settings from unsafe or incomplete state. Product content remains protected.
- Security intake distinguishes passive reading, adoption, and execution.

### Fixed

- Generated release metadata receives the same safe-path checks as other update writes.
- Existing forks can explicitly rejoin the product version and retain their original baseline for comparison.
- Installation dates survive updates, and no-change updates leave files untouched.
- A minor-version bump cannot silently remove 3.0 from the declared transition list.

### Compatibility and limitations

- Standard apply requires independent readable Git history for `os/` and `life/`. A different structure needs an owner-approved adaptation plan rather than a forced rebuild.
- Selected groups use declared dependencies; arbitrary feature-by-feature semantic merging is agent-assisted and requires review.
- Atomic writes protect individual files; interrupted multi-file updates use the complete recovery transaction.
- Local tools do not certify hosted backups, schedulers, every model/harness, or human usability. Those require separate release acceptance evidence.
- Normal installed validation still requires Git. `--foundation` explicitly reports a limited foundation check and never means fully protected setup.

### Updating and rollback

Start from the canonical repository link and follow `setup/UPDATE.md`. Review the owner's current system and agree on the improvement plan. Do not apply a new release merely because it exists. Verify recovery before mutation, validate after apply, and preserve the external transaction until accepted. Use `restore-vault.rb plan` before any approved restoration; it refuses changed backup bytes or later owner work.

## [3.0.0 candidate]

The candidate source was distributed on main at `01f60e03b4ad22b4f9135051df57d73f8a7701f4`. It had no 3.0 version tag or GitHub Release at the September 5 review. The entries below describe that candidate; they do not invent a formal release date.

### Added

- One five-step update contract: **Protect → Review → Ask → Improve → Prove**.
- A five-step new-installation path: **Name → Protect → Create → Personalize → Prove**.
- Rules for reviewing large customized agent-instruction files without overwriting them or replacing them with a summary.
- A required local recovery copy outside the working OS for important content Git does not cover.
- A completion rule that every real `biz/<business>/` is its own Git repository with a verified private hosted primary.
- A fast public-source check for setup and update. The full historical release suite remains a maintainer gate.

### Changed

- Setup now verifies repository, persistence, scheduling, source-access, delivery, and Git capabilities instead of asking owners to choose a local-first, cloud-first, local-on-demand, or hybrid label.
- GitHub is now the normal guided private primary for new owners without a suitable hosted Git service. Existing suitable GitLab or other hosted primaries may be preserved, while local-only Git is reported as incomplete device-loss protection.
- The one-link start now states the capabilities an agent needs and provides a truthful fallback when it cannot read the repository or work with a private repository.
- New installations generate a short owner-named root `AGENTS.md`. That entry belongs to the owner, while `os/AGENTS.md` retains the portable shared rules.
- Updates convert a recognized untouched older root entry once, preserve a customized root entry exactly, and never return the private system to a Starter.OS identity.
- Git setup instructions now put the technical work on the agent and keep sign-in, multifactor authentication, recovery codes, and secret values private with the owner.
- Task reconciliation can fall back to durable project status and owner-provided handoffs when the environment cannot list tasks.
- Public setup files now live under `setup/`. This keeps the public root focused on `os/`, `life/`, and `biz/`.
- Setup and update now classify the public distribution source at completion. An approved temporary checkout can be removed only after proving it contains no owner work; maintainer checkouts and old personal repositories remain intact, and future updates use a fresh canonical source.
- Owner-facing setup language is shorter and technical safeguards remain in agent-only instructions.

### Removed

- Migration is no longer a Starter.OS installation route. An owner with another repository installs a fresh private OS beside it, then may bring over selected context while the old repository stays untouched and backed up.
- The migration guide, migration verifier, and migration-only release tests were removed.

### Fixed

- Public-source routing now uses Starter.OS marker files instead of assuming Git presence identifies the public product.
- The fast source check now ignores harmless computer and temporary working files while continuing to reject unlisted private environment and key material. Agent-configuration folders are flagged for security review instead of silently ignored.
- Project and business generators now identify the public distribution by its release marker, including a downloaded copy with no Git metadata.
- Maintainer documentation now names the correct canonical GitHub repository while preserving the existing GitLab mirror destination.
- Owner personalization now keeps the required `life/wiki/owner.md` path instead of directing agents to rename it.
- Local validation now states clearly that hosted primaries, mirrors, and additional backups require separate verification.
- Installed validation now ignores harmless computer-created root metadata while continuing to reject unknown owner files at the root.

### Security

- Update apply now requires clean, independent Git repositories with readable recovery commits for both `os/` and `life/`.
- Update apply now creates and reads back an external backup of the non-repository root entry files before writing anything.
- The updater now refuses an unversioned folder unless several independent Starter.OS markers identify it; an unrelated repository cannot enter the update path merely because it has `os/` and `life/` folders.
- The recognized pre-versioned root entry is now matched against its real historical digest and transferred to the owner-named form. Customized unversioned root instructions remain byte-for-byte unchanged.
- Update validation now injects a partial-write failure into a plan containing a managed replacement and owner fork, then proves full restoration from Git, the root-backup receipt, and the protected starting inventory.
- Update planning now rejects output paths routed through symbolic-link directories, and root `CLAUDE.md` customizations must use an external owner fork rather than an invalid in-place fork.
- Installed validation now rejects `os/`, `life/`, or a real business without independent Git history and a readable commit.
- New-installation validation proves that an unrelated repository remains unchanged when the private OS is created beside it.
- Installed validation checks the owner root entry by required routing instead of forcing exact Starter.OS wording.

### Compatibility

- Starter.OS does not require a specific agent, model, or environment. A persistent Chief of Staff needs an always-available local or hosted agent with verified access to the repositories, scheduler, sources, and destination.
- Release validation now requires the actual 2.0 and 2.1 release trees from Git history and fails if either update path cannot be proved.
- Versioned 2.0, 2.1, and recognized unversioned Starter.OS installations remain supported through Update.

## [2.1.0] - 2026-08-31

Starter.OS 2.1.0 refines recurring work around persistent home bases while preserving the 2.0 structure and update contract.

### Added

- A single canonical changelog for permanent, version-by-version product history.
- A portable `News Report` recipe for owner-selected sources, citations, plain-language relevance, and `adopt`, `test`, `watch`, or `ignore` recommendations.
- Explicit update coverage for both manifest-managed 2.0 installations and the original unversioned Starter.OS.

### Changed

- Release history now uses an `Unreleased` section and semantic-version categories instead of a separate release-notes file.
- The recurring-work model now centers one persistent Chief of Staff home base and one persistent home base per real project when the execution environment supports them.
- `Morning Brief` is the suggested front-page workflow. It checks authorized calendar, task, project, and week-ahead context, then returns the owner's short check-in to the Chief of Staff home base.
- Task reconciliation now feeds the Morning Brief or an explicit checkpoint instead of producing a separate user-facing report by default.
- The security recipe is now a silent, read-only `System Security Watch` that reports only material findings or incomplete coverage.
- Setup, migration, and update detect available capabilities before suggesting recurring workflows. Owners may adopt, decline, or defer each compatible option, and no provider, source, model, or fixed schedule is required.
- Recurring output prefers an existing persistent destination instead of creating a new task for every run.

### Compatibility

- The 2.1 update path preserves unknown files and owner customizations from 2.0 and unversioned legacy installations. Managed-file conflicts still require an explicit replace, fork, or defer choice.

### Security

- The updater now rejects installed versions not declared by the target release instead of attempting an untested transition.

## [2.0.0] - 2026-08-30

Starter.OS 2.0.0 is the first formally versioned and manifest-managed release.

### Added

- Separate, step-by-step routes for first-time setup, preserve-first migration, and non-destructive update.
- A protected plain-language manual at `os/manual.md` for owners and agents.
- A release manifest that identifies managed and owner-owned artifacts with SHA-256 checksums.
- A deterministic update tool that previews additions, safe managed updates, owner content, forks, conflicts, and deprecated files before applying an approved transition.
- Migration accounting that classifies every source path as preserve, copy, transform, merge, exclude, or unresolved while proving the source remains unchanged.
- Portable skill classifications covering core, optional, scheduled, adapter, private, incomplete, and unsupported material.
- Guided opt-in recipes for `Nightly Chief Reconciliation` and `Nightly System Security Check` in all three owner routes.
- MIT licensing for code and CC BY 4.0 licensing for documentation, the manual, Markdown skills, agent instructions, and templates.

### Changed

- The public repository link alone now starts the guided owner experience.
- Every route discovers existing Git history, remotes, providers, uncommitted work, and recovery coverage before changing anything.
- Each repository uses one chosen primary. Secondary Git services are automatic mirrors, not routine second push targets.
- The portable repository is model- and agent-agnostic. Codex, ChatGPT, Claude, Hermes, Goose, and other file-capable agents are interchangeable execution layers rather than product dependencies.
- Older or heavily customized systems are treated conservatively and never silently assumed to match a trusted baseline.

### Security

- Added a reusable security-intake workflow that keeps newly sourced artifacts inert, treats embedded instructions as data, and protects private files from unapproved public scanning.
- Added read-only, fail-closed guidance for the optional nightly security check.
- Update plans are reconstructed and compared with the current source and target before apply, preventing edited plan actions from bypassing owner-content protections.
- Installation, update, release-building, and installed validation reject unsafe symbolic-link roots and path crossings.
- Public distribution inventory, secret-pattern checks, privacy checks, and source-integrity checks are deterministic release gates.

### Compatibility

2.0.0 supports:

- a clean first-time installation in an empty destination;
- a preserve-first migration from another file-based personal system through the migration map and verifier;
- a manifest-managed 2.0.0 update; and
- a guided update from an unversioned legacy Starter.OS, with every managed file treated as a conflict until the owner explicitly chooses replace, fork, or defer.

The repository contract is portable across file-capable agents. A particular agent, cloud scheduler, connector, operating system, or hosting provider is not called fully supported until its complete setup, working-task, update, recovery, and restore path has been tested.

### Known limitations

- Scheduled routines require an owner-approved scheduler with access to the named sources. If unavailable, setup records the exact gap.
- Automatic mirror setup depends on capabilities available from the chosen primary and secondary providers.
- Local-only Git does not protect against device loss.
- Git does not include ignored, untracked, hidden, or external content unless separately protected.
- The updater stops for an owner choice instead of silently merging modified managed files.
- The free product does not promise one-to-one support or a response time.

### Updating

Paste the public repository link into a file-capable agent. The root `AGENTS.md` routes an existing Starter.OS to `setup/UPDATE.md`.

The update process audits Git and recovery, creates a file-level plan, shows every conflict and owner choice, requires a verified recovery commit, applies only the approved transition, validates the result, commits and pushes only to the primary, verifies enabled mirrors, and offers the two standard automations.

### Rollback

Before apply, record and verify the exact local Git recovery commit for every affected repository and separately protect content Git does not cover.

If validation fails, stop. Restore the affected repository from the named pre-update commit, restore uncovered content from its named backup, run `ruby os/validate-starter-os.rb`, and verify the primary and mirrors before resuming work.

[Unreleased]: https://github.com/ck-os-vaults/starter-os-public/compare/01f60e03b4ad22b4f9135051df57d73f8a7701f4...HEAD
[2.1.0]: https://github.com/ck-os-vaults/starter-os-public/compare/bb7d3c744348c933b03181a7dffa0b6a8c8701ca...v2.1.0
[2.0.0]: https://github.com/ck-os-vaults/starter-os-public/commit/bb7d3c744348c933b03181a7dffa0b6a8c8701ca
