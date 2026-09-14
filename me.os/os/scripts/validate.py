#!/usr/bin/env python3
"""Read-only template/workspace checks. No packages, network, writes, or service claims."""
from pathlib import Path
import argparse
import datetime
import re
from urllib.parse import unquote

REQUIRED = ('AGENTS.md', 'os/AGENTS.md', 'os/CLAUDE.md', 'os/knowledge-map.md',
            'os/retrieval.md', 'os/vault-map.md', 'os/integrations.md', 'os/skills/readme.md',
            'life/AGENTS.md', 'life/knowledge-map.md', 'life/now.md', 'life/wiki',
            'life/projects/readme.md', 'life/documents/readme.md',
            'biz/readme.md', 'os/scripts/readme.md', 'life/records/readme.md', 'life/records/decisions.md', 'life/records/daily')
TOKENS = ('OWNER_NAME', 'WORKSPACE_NAME', 'SETUP_DATE')
RETIRED = ('os/me.md', 'os/recovery.md', 'os/manual.md', 'os/release.json',
           'os/skill-map.md', 'os/starter-os.md', 'os/templates', 'os/owner-skills.md')

def body(text):
    return re.sub(r'```.*?```', '', text, flags=re.S)

def anchors(text):
    result = set()
    counts = {}
    for heading in re.findall(r'^#{1,6}\s+(.+?)\s*#*$', body(text), re.M):
        anchor = re.sub(r'[^\w\- ]', '', heading.lower()).replace(' ', '-')
        n = counts.get(anchor, 0)
        counts[anchor] = n + 1
        result.add(anchor + (f'-{n}' if n else ''))
    return result

def validate(root, workspace=False):
    root = Path(root).resolve()
    distribution = None
    if not workspace:
        distribution = root if (root / 'me.os').is_dir() else root.parent
        root = distribution / 'me.os'
    errors = []
    if distribution:
        for name in ('SETUP.md', 'readme.md', 'LICENSE'):
            if not (distribution / name).is_file(): errors.append(f'Missing wrapper {name}')
    for name in REQUIRED:
        if not (root / name).exists(): errors.append(f'Missing {name}')
    for name in RETIRED:
        if (root / name).exists(): errors.append(f'Retired path: {name}')
    files = list(root.rglob('*.md'))
    if distribution: files += list(distribution.glob('*.md'))
    for f in files:
        if any(x in f.parts for x in ('.git', '.github', 'node_modules', '.venv')): continue
        if 'vendor' in f.parts: continue
        text = f.read_text()
        rel = str(f.relative_to(root)) if root in f.parents else "wrapper/" + f.name
        if workspace and (rel.startswith(('os/', 'life/')) or rel == 'AGENTS.md'):
            for token in TOKENS:
                if token in text: errors.append(f'{rel}: unresolved {token}')
        historical = bool(re.match(r'\d{4}-\d{2}-\d{2}', f.name)) or f.name == 'decisions.md'
        if not historical and rel.startswith(('os/', 'life/')):
            if re.search(r'/Users/|Starter\.OS|me\.os', text, re.I):
                errors.append(f'{rel}: personal/source branding')
        front = re.match(r'---\n(.*?)\n---\n', text, re.S)
        if front:
            for key in ('created', 'updated', 'reviewed'):
                match = re.search(rf'^{key}: (.+)$', front[1], re.M)
                if not match: errors.append(f'{rel}: missing {key}'); continue
                value = match[1]
                if value == 'SETUP_DATE' and not workspace: continue
                try: datetime.date.fromisoformat(value)
                except ValueError: errors.append(f'{rel}: invalid {key}')
        if historical: continue
        for link in re.findall(r'\[[^\]]*\]\(([^)]+)\)', body(text)):
            if re.match(r'[a-z][a-z0-9+.-]*:', link, re.I): continue
            path, _, fragment = link.partition('#')
            target = (f.parent / unquote(path)).resolve() if path else f
            if not target.exists(): errors.append(f'{rel}: missing link {link}')
            elif fragment and target.suffix == '.md' and unquote(fragment) not in anchors(target.read_text()):
                errors.append(f'{rel}: missing heading {link}')
    return errors

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', nargs='?', default=str(Path(__file__).resolve().parents[2]))
    parser.add_argument('--workspace', action='store_true', help='Require personalized values')
    args = parser.parse_args()
    errors = validate(args.root, args.workspace)
    print('\n'.join(errors) if errors else 'PASS: required files, active Markdown paths/headings, dates, and template hygiene.')
    raise SystemExit(bool(errors))
