#!/usr/bin/env python3
"""Synthetic fixture checks; does not simulate an agent, login, or hosted backup."""
import shutil
import tempfile
import unittest
from pathlib import Path
from validate import validate

SOURCE = Path(__file__).resolve().parents[1]
class TemplateChecks(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name) / 'Morgan workspace'
        self.root.mkdir()
        for area in ('os', 'life'): shutil.copytree(SOURCE / area, self.root / area)
        (self.root / 'AGENTS.md').write_text('Use [shared instructions](os/AGENTS.md).\n')
        replacements = {'OWNER_NAME':'Morgan', 'WORKSPACE_NAME':'Morgan workspace',
                        'TIME_ZONE':'Europe/London', 'SETUP_DATE':'2026-09-13'}
        for f in self.root.rglob('*.md'):
            text = f.read_text()
            for old, new in replacements.items(): text = text.replace(old,new)
            f.write_text(text)
    def tearDown(self): self.tmp.cleanup()
    def test_source(self): self.assertEqual([], validate(SOURCE))
    def test_personalized_workspace(self): self.assertEqual([], validate(self.root, True))
    def test_unresolved_context_fails(self):
        with (self.root/'os/AGENTS.md').open('a') as f: f.write('OWNER_NAME\n')
        self.assertTrue(any('unresolved' in x for x in validate(self.root,True)))
    def test_broken_path_fails(self):
        with (self.root/'life/now.md').open('a') as f: f.write('[Missing](missing.md)\n')
        self.assertTrue(any('missing link' in x for x in validate(self.root,True)))
    def test_broken_heading_fails(self):
        with (self.root/'life/now.md').open('a') as f: f.write('[Missing](knowledge-map.md#missing)\n')
        self.assertTrue(any('missing heading' in x for x in validate(self.root,True)))
    def test_old_structure_fails(self):
        (self.root/'os/me.md').write_text('Old identity\n')
        self.assertTrue(any('Retired path' in x for x in validate(self.root,True)))
    def test_existing_content_relocated(self):
        original = b'# Garden notes\n\nKeep the cherry tree.\n'
        old = self.root/'old-notes'; old.mkdir()
        (old/'garden.md').write_bytes(original)
        backup = Path(self.tmp.name)/'backup'; shutil.copytree(self.root,backup)
        project = self.root/'life/projects/garden'; project.mkdir()
        shutil.move(old/'garden.md',project/'garden.md'); old.rmdir()
        with (self.root/'life/projects/readme.md').open('a') as f: f.write('\n[Garden](garden/garden.md)\n')
        self.assertEqual(original,(project/'garden.md').read_bytes())
        self.assertEqual(original,(backup/'old-notes/garden.md').read_bytes())
        self.assertEqual([],validate(self.root,True))
    def test_personal_data_fails(self):
        with (self.root/'os/AGENTS.md').open('a') as f: f.write('/Users/example/private\n')
        self.assertTrue(any('branding' in x for x in validate(self.root,True)))

if __name__ == '__main__': unittest.main()
