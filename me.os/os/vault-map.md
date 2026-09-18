---
type: map
created: SETUP_DATE
updated: SETUP_DATE
reviewed: SETUP_DATE
status: living
authority: canon
source: ai
---

# Vault map

[← Knowledge map](knowledge-map.md)

Use this map for file placement, repository boundaries, and recovery.

## Structure

```text
WORKSPACE_NAME/       plain workspace container
├── os/              shared guidance repository
├── life/            personal repository
└── biz/             business container
    └── <business>/  independent business repository
```

The workspace root and `biz/` are plain containers. Each listed repository has independent history. Keep existing repository boundaries when adapting an established workspace; update this map to its actual layout.

## Repository inventory

Record the actual local workspace root here during setup; repository paths below are relative to it.

| Path | Private remote | State |
|---|---|---|
| `os/` | Set during setup | Not verified |
| `life/` | Set during setup | Not verified |

Record actual destinations and the last verified sync. A configured remote alone does not prove backup health.

## File ownership

| Information | Home |
|---|---|
| Shared operating guidance | `os/` |
| Cross-project personal priorities | [Now](../life/now.md) |
| Durable personal knowledge | `life/wiki/` |
| Personal project work | `life/projects/<project>/` |
| Supporting personal documents | `life/documents/` or the owning project |
| Daily continuity and decisions | [Records](../life/records/readme.md) |
| Business work | Its own `biz/<business>/` repository |

Use lowercase kebab-case paths and date-named daily notes. Keep useful content in one owning location and link to it.

## Restore and verify

Clone the private repositories into the recorded paths, restore separately backed-up files, and verify the links, latest commits, and actual project checks before resuming work. Preserve unpublished work before any restore or sync. Investigate divergent history instead of overwriting it.

Git does not back up uncommitted or unpushed changes, ignored attachments, root entry files, app settings, or credentials. Record the actual separate backup method in [integrations](integrations.md); mark missing protection honestly.

### Root entry files

The plain workspace root is outside the individual repositories. After restoring them, recreate a standard root AGENTS.md with: “Use os/AGENTS.md for shared instructions and the relevant project AGENTS.md for local context.” A standard root README can link to `os/knowledge-map.md`, `life/knowledge-map.md`, and `biz/readme.md`.

These directions recover only the standard entry files. Keep customized root content in the existing separate backup and record its verified destination here. Restore customizations before resuming work; do not replace them with the standard text. If protection is incomplete, say exactly what is missing.
