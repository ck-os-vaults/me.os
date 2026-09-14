# me.os

A simple starting point for a personal workspace your agent can help you run.

Give your agent this link and say:

> Read https://github.com/ck-os-vaults/me.os, find SETUP.md, and set up my personal workspace. Ask me the short interview together, then handle the rest.

[SETUP.md](SETUP.md) is the complete setup workflow. Use an agent that can read the repository, edit your files, and run Git. It will use what you already have, ask a few questions, and organize your own private workspace.

## What you get

| Home | Purpose |
|---|---|
| `os/` | Your agent instructions, navigation, integrations, and memory guidance |
| `life/` | Your context, current priorities, projects, decisions, and daily notes |
| `biz/` | Separate business work, created when needed |

The finished workspace uses your name and context. No product account, paid license, update subscription, or connection back to this repository is required. Your AI and other services may have their own costs.

## After setup

Work with your agent normally. It maintains current context and useful daily records as you work. You own the files and can change the structure and instructions.

Improvements here benefit new setups. Existing users can ask their agent to adopt a specific improvement; there is no automatic updater or template sync.

## Maintaining this template

Edit the universal files and the single setup workflow. Run `python3 scripts/validate.py` and `python3 scripts/test_template.py` before publishing. These checks validate the template and a synthetic personalized fixture; they do not establish that every agent or computer can complete setup.

The old releases remain historical Git references, not the setup route. This template uses the [MIT license](LICENSE). Maintainer scripts, repository history, and `.github/` are not installed into personal workspaces.
