---
type: manual
created: 2026-08-30
updated: 2026-09-05
reviewed: 2026-09-05
status: living
authority: reference
source: starter-os
---

# How Starter.OS works

This protected manual explains your foundation. An agent may read and explain it, but may not rewrite or personalize it during normal work.

## Your second brain and Chief

Your files hold lasting knowledge, preferences, decisions, and project context. Chief is the AI coordination role that helps you work with them. You choose its name and tools. Your judgment and direction shape the system; the agent handles the mechanical work within your approval.

An agent is the tool doing work; a model is the AI engine it uses; a harness or app supplies its tools and execution. These can change while your durable information stays yours. Actual permissions, connections, schedules, and capabilities need separate verification in each environment.

## Where information lives

- `os/` holds operating guidance, preferences, skills, validation, and recovery.
- `life/` holds personal notes, knowledge, decisions, and projects.
- `biz/` holds real businesses, added only when needed.

Your private system takes your chosen name. Root `AGENTS.md` belongs to you and points to `os/AGENTS.md`, `os/me.md`, nearest project/business instructions, and `os/release.json` for upstream identity. Keep lasting personal rules in their protected home. The root itself is not a Git repository, so its small entry files need full-file backup.

A project is work with a real outcome; a business has its own context and repository. Each gets one clear home. Extra personal content and reviewed agent settings are preserved. A notice about old folders or custom layout invites review, not deletion. The public `setup/` folder belongs only to the installer.

## Installation

Give an agent the public repository link. It inspects first and guides **Name → Protect → Create → Personalize → Prove**. It explains the foundation, recommends private backup early, and asks for the meaningful choices together. Sign-ins and secret values stay private with you.

Setup ends when the foundation and its protection status are verified and explained. It may suggest useful optional improvements, which you can approve, decline, or defer. No real task, example project, exercise, or automation is required. You choose your first task afterward.

An unrelated old repository remains separate and unchanged. After setup, you can ask to bring over selected context. Do not use a public fork for private work.

## Git, backup, and recovery

Git is file history. A repository is a folder with that history; a commit is a recorded checkpoint. Local Git helps recover bad edits, but does not protect against device loss. A private hosted primary keeps an off-device copy. GitHub is the guided default; another suitable private host can stay. A mirror is an optional automatic downstream copy. Agents push only to the approved primary.

The standard protected system has separate repositories for `os/`, `life/`, and each business. You can decline or defer Git during a new installation. The agent records missing protection honestly and offers alternatives without repeatedly asking. Later changes that need recovery still require it.

Git does not cover every ignored, untracked, hidden, root-level, or external file. Full-file backup closes those gaps. A successful upload is not a restore test. See `recovery.md` for verified facts, missing coverage, and where recovery material lives. Credentials are recovered through your credential manager, never the vault.

## Skills, integrations, and automations

A skill is a saved method for repeated work. Product skills are listed in `skill-map.md`; your personal skills live in `skills/` and are registered in owner-owned `owner-skills.md`. Adding a personal method should not require editing a protected product file.

An integration connects another service. An automation runs accepted work on a schedule. Neither becomes active merely because a recipe is installed. Optional recipes include a Morning Brief, a cited News Report, System Security Watch, and cross-project reconciliation. Planning and questionnaires are choices, not compulsory Chief behavior. Security Watch stays read-only, quiet when checks finish cleanly, and reports incomplete coverage.

Accepted routines need verified sources, permissions, runtime, schedule/timezone, and destination. Prefer existing task homes and update equivalents instead of creating duplicates. Declines and deferrals are remembered in `integrations.md`. Optional services may have their own costs.

## Updates improve your system through agreement

A new release is reference material for your agent and you. It does not authorize replacing your system with a template. Follow **Protect → Review → Ask → Improve → Prove**:

1. Protect current files with a verified recovery route.
2. Compare your original release, actual customizations, and available improvements.
3. Agree on meaningful changes, dependencies, and any adaptations or deferrals.
4. Apply only that plan.
5. Verify preservation and explain the result and recovery route.

Personal files and preferences stay yours. Unchanged product files are eligible for an approved update; eligibility alone is not permission. A changed product file needs a decision. A fork is your explicitly customized version: keep it, reconcile it, or return to the reviewed upstream version. The original baseline stays available when known, and later improvements should still be visible.

Selected improvement groups may be adopted without taking the full release. Their dependencies must fit. A highly customized system may need an agent-assisted adaptation instead of the standard updater. The receipt distinguishes selected changes from full release adoption. Your instructions must never be silently replaced or summarized away.

## Validation and restoration

Validation checks local structure, required routing, registries, release identity, protected files, and readable Git history, and checks active files for common secret patterns. It does not prove every link, every privacy risk, hosted backup, or working schedule. Those need separate review. Foundation-only validation reports deferred Git and cannot certify full protection.

An update creates an external transaction backup with the original commits, root entries, original and proposed write bytes, and an inventory. Its restore preview refuses to discard later owner work or use changed backup bytes. Restoration changes only the update's recorded paths and verifies the protected inventory. It does not reset remote history. Keep recovery until you accept the update.

## Permissions and the manual

Your agent may do ordinary reversible work within an approved task. It asks for meaningful choices and authority for structural changes, deletion, messages, publication, spending, access changes, private-data movement, and automation. Approval continues for the same unchanged actions. Checking an update is not permission to apply it.

This manual explains; current owner instructions and the declared operating hierarchy control behavior. It is managed by Starter.OS. If you want a personal explanation, explicitly create an owner-owned fork such as `life/manual.md` and route it from `os/me.md`. The approved manual-fork update does that routing within its recovery transaction. Future updates keep the product manual available for comparison.

When unsure, ask Chief to explain the relevant part and the next necessary choice.
