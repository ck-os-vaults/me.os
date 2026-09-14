# me.os

A simple starting point for a personal workspace your agent can help you run.

Give your agent this link and say:

> Read https://github.com/ck-os-vaults/me.os, find SETUP.md, and set up my personal workspace. Ask me the short interview together, then handle the rest.

[SETUP.md](SETUP.md) covers both fresh setup and improvements to an existing workspace. Use an agent that can read the repository, edit your files, and run Git. For a fresh setup, it asks a short interview and organizes your private workspace. For an existing system, it compares the instructions and proposes useful changes while preserving your context and customizations.

## What you copy

For a fresh setup, copy the contents of [me.os/](me.os/) into your own named workspace. The repository wrapper holds the setup instructions and license; it is not part of your personal vault.

```text
repository/
├── SETUP.md
├── LICENSE
├── readme.md
└── me.os/
    ├── AGENTS.md
    ├── CLAUDE.md
    ├── os/
    ├── life/
    └── biz/
```

## What you get

| Home | Purpose |
|---|---|
| `os/` | Your agent instructions, navigation, integrations, and memory guidance |
| `life/` | Your context, current priorities, projects, decisions, and daily notes |
| `biz/` | Separate business work |

The finished workspace uses your name and context. No product account, paid license, update subscription, or connection back to this repository is required. Your AI and other services may have their own costs.

## After setup

Work with your agent normally. It maintains current context and useful daily records as you work. You own the files and can change the structure and instructions.

To improve an existing system later, give your agent the repository link and say:

> Read SETUP.md and use its existing-workspace path to compare your latest guidance with my system. Propose useful improvements while preserving my context and customizations.

The agent adapts agreed changes into your files. There is no automatic updater or template sync.

## Maintaining this template

Edit the universal files and the single setup workflow. Run `python3 me.os/os/scripts/validate.py` and `python3 me.os/os/scripts/test_template.py` before publishing. These checks validate the template and a synthetic personalized fixture; they do not establish that every agent or computer can complete setup.

The old releases remain historical Git references, not the setup route. This template uses the [MIT license](LICENSE). Repository history and `.github/` are not installed into personal workspaces.
