# Starter.OS

A free foundation for your own second brain and AI Chief of Staff.

Your files hold lasting knowledge, preferences, decisions, and project context. Your chosen agent helps you work with them. You shape the system through use, keep control of your information, and can change models or tools without rebuilding your knowledge.

The current `main` branch contains the **3.1.0 candidate** for owner testing. To try this newest candidate, tell your agent: “Use the current 3.1 candidate on main and guide me through setup.” This selects the version; the agent still reviews your setup plan with you before creating files. Local checks pass, and independent-review findings have been addressed. Real-user and hosted-service acceptance remain in progress.

## Start with one link

Give a file-capable agent this repository:

**https://github.com/ck-os-vaults/starter-os-public**

The link is the entire prompt. You can also say:

> Check this out and find the install that fits us best.

The agent reads `AGENTS.md`, checks what you already have and what your tools can do, then guides a new installation or an update. You do not need to find a setup file, choose a technical architecture, or learn Git commands. If the agent cannot read the instructions or work in your private files, it must explain the missing capability. A fallback is: “Read the root AGENTS.md and guide me through the appropriate route.”

## Your foundation

- `os/`: operating guidance, preferences, reusable workflows, and recovery.
- `life/`: personal knowledge, notes, and projects.
- `biz/`: businesses, created only when you need them.

Your private system takes your chosen name. Setup establishes protection early, adds confirmed preferences, checks the foundation, and explains how to begin. You choose your first task afterward. Projects, example exercises, and automations are not required.

Private GitHub repositories are the recommended starting protection. An existing suitable host can stay. You can decline or defer; the agent explains what remains unprotected without repeatedly asking. You handle sign-in and secrets privately. The agent handles technical steps within your approval.

## Updates respect your system

A new release is reference material for an implementation plan you agree on with your agent. It does not authorize replacing your system with a new template. Review relevant benefits, dependencies, and effects; adopt, adapt, decline, or defer improvements. Apply only the agreed plan with verified recovery. Your preferences, files, and customizations remain yours.

## Tools, privacy, and cost

Starter.OS is free. AI subscriptions and external services may have separate costs. No specific model or harness is required; use verified capabilities in the environment you already have. Cloud AI can help operate owner-controlled files. Scheduled work needs an available runtime and separately verified access.

This public repository is a blueprint, never your private working copy. Do not personalize it or use a public fork to hold private information. Never store passwords, tokens, recovery codes, or private keys in the system or chat.

## Releases and maintainers

Normal setup uses an approved released source resolved to its exact commit. This checkout's `setup/release-manifest.json` identifies its version and release status. Unreleased candidates require an explicit choice; tools refuse candidate writes without `--allow-unreleased`. A mutable main branch is not proof of a released version.

See [CHANGELOG.md](CHANGELOG.md) for changes, compatibility, limitations, and recovery. Run `ruby setup/scripts/validate-starter-kit.rb` for the complete local release suite. Human setup, hosted recovery, schedules, and environment support require separate acceptance evidence.

Software uses [MIT](setup/legal/LICENSE-CODE); documentation, skills, and templates use [CC BY 4.0](setup/legal/LICENSE-CONTENT). [LICENSE](LICENSE) explains attribution and marks.
