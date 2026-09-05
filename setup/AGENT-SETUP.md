# Establish a private foundation

> **Audience: Agent only.** The owner starts with the public link, optionally asking which install fits. Read the public `AGENTS.md`, `readme.md`, and the shared `GIT-SETUP.md`. Explain choices briefly; perform the technical work within approved capabilities.

## 1. Name

Inspect existing systems, approved private file access, Git, and the Ruby runtime. Confirm the owner-chosen name and empty destination ending in `.os` (case is preserved). The folder name becomes the private system's name. Use Update for a recognized Starter.OS. Leave an unrelated repository untouched and choose a separate empty location.

Collect only the name, destination, and immediately useful confirmed preferences. Do not require a project, first task, example exercise, or architecture label.

## 2. Protect

Validate the selected source:

```sh
ruby setup/scripts/validate-source.rb
```

Follow `GIT-SETUP.md`: discover Git and current recovery, explain the recommended private primary, and establish approved account/repository access early. GitHub is the guided default, not a mandatory provider. Preserve an existing suitable host. Let the owner decline or defer protection; state the limitation once and record it.

Show one compact plan: exact name and destination, private repository actions, privacy, protection or declined coverage, and what files setup will create. Reuse approval for those same actions. Request another decision only if new evidence changes the scope. The owner handles sign-in privately; never ask for secrets in chat.

Use the current 3.1.0 release by default, resolved through `v3.1.0` to its exact commit. No version question or special creation flag is needed. Future unreleased builds still need an explicit owner choice and `--allow-unreleased`; their presence on main is not that choice.

## 3. Create

After approval, create the minimal scaffold:

```sh
ruby setup/scripts/create-vault.rb /absolute/path/to/NAME.os
```

The private root contains owner-named `AGENTS.md`, a thin `CLAUDE.md` pointer, `os/`, `life/`, and empty `biz/`. No `setup/` is installed. The root entry belongs to the owner. Keep it short and put lasting owner facts in Git-protected context; include root entries in full-file backup.

Immediately initialize the approved independent `os/` and `life/` repositories, review the baseline for private/secret material, commit, read back the recovery commits, and verify the approved private hosted copies. Do this before substantial personalization. The initial files must exist before their first commit can be verified. If protection was declined, do not initialize or publish anyway.

The approved plan already authorizes adoption of this same scaffold; do not add a second adoption interview.

## 4. Personalize

Add only confirmed context:

- Collaboration preferences and chosen Chief name: `os/me.md`.
- Personal state, if supplied: `life/now.md`.
- Durable background, if supplied: `life/wiki/owner.md`; keep the path.
- Personal reusable skills: `os/skills/`, registered in owner-owned `os/owner-skills.md`.
- Actual capabilities and optional routines: `os/integrations.md`.
- Verified, declined, deferred, or missing protection: `os/recovery.md`.

Never edit managed files just to personalize them, including `os/manual.md` and the product skill map. Owner-specific methods have their own homes. Projects and businesses are created later on request through the installed helpers; each real business needs its own protection.

Offer only a few relevant optional improvements. The owner may adopt, decline, or defer. Use existing choices and actual repository, runtime persistence, scheduler, source-access, and delivery capabilities; do not inventory unavailable services just to fill a form. Accepted recurring work follows its portable recipe, returns to an existing home when supported, and is separately verified. Never create an automation just because a recipe exists.

## 5. Prove and hand off

Run:

```sh
ruby os/validate-starter-os.rb
```

For an explicit Git deferral or opt-out, use `--foundation`. It checks the foundation while reporting missing Git history, and never proves fully protected setup. A clean but unreadable Git repository still needs correction. Verify hosted primaries, accepted mirrors, full-file backups, and restore access separately.

Review the intended diff and protect the approved personalization. Give a short receipt: system location and source identity, confirmed preferences, validation, actual protection, unresolved gaps, and optional decisions. Apply the source-cleanup rules in `GIT-SETUP.md`.

Explain where information lives, how to start with Chief in ordinary language, and how future updates are reviewed. Setup is complete when the foundation and its protection status are understood and verified to the stated scope. No real task, tutorial exercise, project, or automation is required. The owner chooses what to do next.

If requested later, bring over what matters from an old repository through reviewed copies while the old repository remains unchanged and backed up.
