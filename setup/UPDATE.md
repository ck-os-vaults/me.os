# Improve the owner's existing system

> **Audience: Agent only.** Read the public `AGENTS.md` and shared `GIT-SETUP.md`. Keep the conversation to **Protect → Review → Ask → Improve → Prove**.

A new release is reference material for a plan agreed with the owner. It does not authorize rewriting their system to match the template. Preserve their files, personal instructions, structure, and working behavior unless an exact change is included in the plan. A request to check or review an update grants no update-write authority.

## 1. Protect

Validate the selected source:

```sh
ruby setup/scripts/validate-source.rb
```

Use the current 3.2.0 release by default. Resolve the canonical repository's `v3.2.0` release tag to its immutable commit and match the manifest identity. The current release needs no version choice or special apply flag. A future unreleased build requires an explicit choice before adding `--allow-unreleased` to apply.

Inspect the installed root instructions and `os/release.json`. Recognized unversioned Starter.OS is supported conservatively; generic `os/` and `life/` folders do not prove its identity. An unrelated repository remains untouched. Check actual files, Git topology, and all relevant current work through `GIT-SETUP.md`. A read-only plan may identify issues before recovery exists, but no material target mutation is allowed until its recovery prerequisites are verified.

Standard apply requires clean independent `os/` and `life/` repositories with readable commits. Preserve a different topology; do not rebuild it merely to run the updater. Prepare the separate local non-Git backup, hosted proof, and exact restore route before writes.

## 2. Review

Compare the original installed release, the owner's current system, and the proposed release. The source manifest lists immutable historical baselines. The installed record retains hashes, source versions, original installation identity, and fork baselines where known. Missing historical evidence is uncertainty, never permission to infer an untouched file. Without a trusted installed record, the tool deliberately reports existing managed paths as conflicts. The agent must compare available immutable historical product bytes and read the owner's changes, then group verified stock replacements and preserved customizations into the one agreed plan. Do not turn the raw conflict list into a file-by-file owner interview or a blanket replacement command. When a baseline or personal meaning cannot be established, preserve it and propose adaptation or deferral.

Create a deterministic proposal outside source and target:

```sh
ruby setup/scripts/update-vault.rb plan /absolute/path/to/NAME.os /absolute/path/to/update-plan.json
```

This is a full proposal, not an instruction to apply everything. Explain only meaningful improvements, behavior changes, dependencies, and genuine conflicts. The plan includes selected groups and a protected local inventory. Unknown files, seed-only content, and local customizations remain untouched unless an exact change is approved.

Selected adoption is validated for 3.0, 3.1, and 3.2 bases. Earlier versioned and unversioned bases use a full reviewed transition, or a separately reviewed agent adaptation; the tool refuses unvalidated partial combinations.

For selected improvements, create a new proposal using the groups declared in `setup/release-manifest.json`:

```sh
ruby setup/scripts/update-vault.rb plan /absolute/path/to/NAME.os /absolute/path/to/selected-plan.json --only news-report
```

Repeat `--only GROUP` for more groups. The tool includes declared dependencies and reports the actual selection. Current groups are `governance`, `validation`, `foundation`, `project-tools`, `morning-brief`, `news-report`, `work-wrap`, `reconciliation`, and `security-watch`. Selected improvements include the small validation and shared-governance dependencies, not the entire foundation. Validation includes an absent owner-registry seed. A customized old validator needs an exact compatible adaptation or reviewed replacement. Installing a recipe never enables a routine. Partial adoption retains the previous base version and records the adopted group/source identity; it is not full release adoption.

On the first owner-controlled transition, reconcile legacy product-imposed maintenance restrictions in `os/AGENTS.md`. Unchanged shared rules can adopt the reviewed source. Customized shared rules need an exact reviewed adaptation that retains unrelated owner instructions and explicitly supersedes only obsolete product restrictions; `--keep` alone cannot establish this transition. An already-compatible owner version may use a byte-identical candidate with preservation notes. Do not remove the owner's independently chosen protections. Root entry bytes and the rest of the foundation stay unchanged unless separately included in the approved plan. This is a narrow compatibility dependency, not permission to replace a personalized foundation.

For extensive customization that cannot use this updater, stop the standard tool and propose a separate bounded adaptation of selected improvements within the owner's layout. Preserve and verify all affected content. Do not claim full version compatibility or silently change their structure. This is owner maintenance within Update, not a third installation route.

## 3. Ask

Agree on one compact implementation plan: relevant benefits, exact affected locations, preserved behavior, dependency groups, real conflicts, recovery, Git actions, and any cleanup. Reuse existing authority for that same reviewed scope. The owner can adopt, adapt, decline, or defer. Do not interview them about every file or repeat previously declined routine suggestions.

All installed content belongs to the owner. Baselines are provenance, not edit restrictions. For a modified source-derived file, preserve it by default and offer only useful choices:

- Adapt the relevant improvement to the existing owner-controlled file.
- Keep the owner's version in place, without a fork ceremony.
- Replace with the reviewed upstream file.
- Defer the affected group or the update.

Large customized instructions must be read for meaning, preserved fully, and never replaced by a summary. For each instruction removed or consolidated, temporary review notes must identify its surviving authoritative home or explicit removal approval. Read the claimed home before calling content redundant. The owner root `AGENTS.md` is preserved byte for byte unless an exact adaptation is approved. Only a recognized untouched historical product root may receive its one-time ownership transfer. Existing forks retain their baseline and routes; relevant new upstream changes must be explained.

### Exact reviewed adaptations

Prepare candidate files and preservation notes outside both source and target. The notes explain the behavior preserved, the authoritative homes for any consolidated instructions, explicit removals, validation, and owner approval. Then bind those exact inputs into a new plan:

```sh
ruby setup/scripts/update-vault.rb plan /absolute/path/to/NAME.os /absolute/path/to/adapted-plan.json --only foundation --adapt os/manual.md=/absolute/path/to/reviewed-manual.md --review /absolute/path/to/preservation-notes.md
```

Repeat `--adapt PATH=EXTERNAL_FILE` for each reviewed candidate. Standard adaptations cover regular files inside protected `os/` and `life/`, plus root `AGENTS.md` and `CLAUDE.md`. Select the declared group of any adapted release artifact. Other owner files in that scope are explicitly listed, not silently added. Generated metadata, hidden configuration, symlinks, case aliases, nested repositories, and other destinations are refused. Do not use this path to rewrite Git configuration or move repository boundaries. Review the final plan and inputs; edits require a new plan. This is exact adoption, not automatic semantic merging.

## 4. Improve

Apply only the agreed plan:

```sh
ruby setup/scripts/update-vault.rb apply /absolute/path/to/NAME.os /absolute/path/to/update-plan.json --root-backup /absolute/path/to/new-update-backup
```

For each genuine conflict, or an explicit choice about preserved customization, use `--keep PATH`, `--replace PATH`, or legacy `--fork SOURCE=DESTINATION`. Modified files otherwise stay in place. A checksum match makes a source-derived file eligible, not authorized outside the plan. Source, target, plan, candidate files, preservation notes, and inventory are rechecked before writes.

Custom `os/manual.md` and root `CLAUDE.md` remain valid in place. Keep an already-routed personal manual at its actual home. There is no mandatory manual copy or adapter relocation. The older copy operation remains available only when the owner explicitly wants it, for example:

```sh
ruby setup/scripts/update-vault.rb apply /absolute/path/to/NAME.os /absolute/path/to/update-plan.json --root-backup /absolute/path/to/new-update-backup --fork os/manual.md=life/manual.md
```

A manual fork also adds its route to `os/me.md` within this transaction; include that owner-file addition in the approval. For the root adapter use `--fork CLAUDE.md=life/claude-entry.md`. Fork copies must stay inside `os/` or `life/`, the repositories covered by this transaction. No arbitrary owner file, Git metadata, generated release metadata, existing destination, or unselected artifact may be overwritten as a fork destination.

Keep the entire external transaction backup, including adaptation preservation notes. Direct and adapted writes share the same before/after staging, protected inventory, and restore path. Selected or adapted adoption retains the original base and installation identity. Format-2 adoption records make older updaters refuse without writing, including after a partial update; do not edit the record to bypass that safeguard. No-change updates leave the installation and its dates untouched. Do not push until validation and preservation checks pass and publication is authorized.

## 5. Prove, or restore

Run installed validation, compare the actual diff with the approved plan, and verify preserved owner meaning:

```sh
ruby os/validate-starter-os.rb
```

The updater checks that only its declared writes changed the local inventory. Installed validation checks operational health, local links, registries, and declared recovery repository paths. It does not require owner files to match release bytes. Public-source integrity is checked separately. Neither check proves hosted primaries, mirrors, external backups, schedules, or semantic meaning; verify those separately.

On interruption or failed checks, stop and inspect the complete recovery transaction:

```sh
ruby setup/scripts/restore-vault.rb plan /absolute/path/to/NAME.os /absolute/path/to/new-update-backup
ruby setup/scripts/restore-vault.rb apply /absolute/path/to/NAME.os /absolute/path/to/new-update-backup
```

Apply restoration only with authority for that concrete plan. It verifies saved bytes, original repository commits, staged work, and changes since the transaction. It restores only transaction writes and removes only its own new paths/directories, then proves the full protected inventory matches. It refuses later owner edits, new files, changed commits, or altered backup bytes. Preserve that later work and agree on a recovery plan rather than bypassing the refusal. Restore does not rewind remote history. Re-run the restored version's validator and separately verify hosted state before resuming.

Give one short receipt: previous base, adopted release or selected improvements, preserved work, choices/deferred changes, validation, actual protection, backup and rollback route, routine outcomes, and source cleanup. Keep recovery until the owner accepts the result. The goal is their working system improved through an understood plan.
