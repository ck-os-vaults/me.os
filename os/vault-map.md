---
type: map
created: 2026-08-29
updated: 2026-09-05
reviewed: 2026-09-05
status: living
authority: canon
source: ai
---

# vault map

**Bottom line:** One vault contains shared operating context in `os/`, the owner's personal world in `life/`, and independently owned businesses in `biz/`.

**When to read this:** Read before creating, moving, renaming, removing, or changing a repository boundary.

```text
name.os/                 plain vault container; never a Git repository
├── AGENTS.md             generated agent entry
├── CLAUDE.md             thin agent adapter
├── os/                   shared OS repository
│   ├── manual.md         protected plain-language explanation
│   ├── license.md        product license and attribution notice
│   ├── release.json      generated installed-version record
│   ├── skills/           portable reusable workflows
│   └── templates/        managed starting structures
├── life/                 personal repository
└── biz/                  plain container; never a Git repository
    └── <business>/       one repository for each confirmed real business
```

Owner-chosen app and agent settings such as `.obsidian/`, `.codex/`, `.claude/`, or `.agents/` may exist. Preserve them and review permissions before enabling them; their presence grants no execution authority. The public `setup/` folder contains installation files and never belongs in an installed vault.

## Routing

| Material | Owner |
|---|---|
| shared rules, manual, maps, templates, or portable workflow | `os/` |
| installed release identity | `os/release.json` |
| current personal state | `life/now.md` |
| durable personal knowledge | `life/wiki/` |
| active personal work | `life/projects/<project>/` |
| retained personal document without a clearer owner | `life/documents/` |
| durable personal decision | `life/records/decisions.md` |
| business material and implementation | `biz/<business>/` |
| obsolete material | remove only after approval and verified recovery |

Unknown files are owner-owned. Do not create a catch-all inbox or archive by default. Preserve an owner-created archive; its name does not make its contents obsolete. If ownership is unclear, ask whether the material belongs to an existing project, a new real project, Wiki, Documents, or a business.
