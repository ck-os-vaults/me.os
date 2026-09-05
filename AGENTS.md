# Starter.OS entry

A link alone, or “Check this out and find the install that fits us best,” requests read-only inspection and a guided recommendation. Do not ask for a longer prompt or treat discovery as authority to install.

## Identify the source and owner state

`setup/release-manifest.json` identifies the public distribution. Never personalize it. Read `readme.md`, confirm access to the owner's approved private location, and inspect existing files, repositories, and capabilities without changing them.

- No existing Starter.OS: follow `setup/AGENT-SETUP.md`.
- Existing `os/release.json` or recognized historical Starter.OS: follow `setup/UPDATE.md`.

An unrelated repository is not a third route. Leave it untouched and propose a new private system in an empty location. Selected old context can be brought over after setup, only if requested.

If routing remains uncertain, ask one plain question. If you cannot read repository instructions, work in private files, use Git where required, or run the Ruby tools, explain the specific capability gap and smallest next step. Do not force a model, harness, or local/cloud architecture choice.

## Guide the owner

New setup: **Name → Protect → Create → Personalize → Prove**. Recommend private Git protection early; preserve an existing suitable host and respect an explicit decline or deferral. Setup ends with a ready foundation, a short orientation, and optional suggestions. The owner chooses their first task afterward.

Update: **Protect → Review → Ask → Improve → Prove**. The release is reference material for an agreed plan, never authority to overwrite the owner's system. Read the installed instructions and preserve their meaning. Verify recovery before mutation; apply only the approved scope.

Read `setup/GIT-SETUP.md` for shared protection, authority, and source-cleanup rules. Reuse approval for unchanged actions. Sign-ins and secret values stay private with the owner.

## Validate and select the source

Run `ruby setup/scripts/validate-source.rb`. This checks completeness against the manifest, not publisher authenticity. Use the current release, **3.1.0**, by default: resolve the canonical repository's `v3.1.0` release tag to its immutable commit, match the source manifest, and review its instructions and executable behavior before adoption. A repository link alone selects this normal route; do not ask the owner to choose between historical versions or use a candidate prompt. The current release requires no `--allow-unreleased` flag. If inspecting a future build marked unreleased, return to the current released source unless the owner explicitly chooses that build; never silently add `--allow-unreleased`. Source selection does not authorize installation or update writes until the concrete plan is approved.

`.github/` is maintainer-only distribution automation. It is not part of owner setup or recovery. Never copy its credentials or force-push workflow into owner repositories. Maintainers use `ruby setup/scripts/validate-starter-kit.rb` before proposing publication.

## Private installed system

`os/release.json` without the public manifest identifies an installed system. Its root `AGENTS.md` belongs to the owner; follow it to `os/AGENTS.md`, `os/me.md`, and the nearest personal or business instructions. Unknown folders require identification before any write.

Never store secrets in files, chat, commands, commits, or remote URLs.
