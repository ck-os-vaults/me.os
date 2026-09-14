# Scripts

Small checks your agent can run to catch missing files, broken links, invalid dates, and leftover setup details. You do not need to edit them.

| File | Purpose |
|---|---|
| `validate.py` | Checks the workspace’s files and navigation |
| `test_template.py` | Exercises the checks with a fictional workspace |

From the workspace root, run `python3 os/scripts/validate.py --workspace`. Your agent can run `python3 os/scripts/test_template.py` when changing the checks. These commands do not modify your files or verify online backups.

[← Knowledge map](../knowledge-map.md)
