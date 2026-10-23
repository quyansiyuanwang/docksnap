#!/usr/bin/env python3
"""Tests for scripts/changelog.py, using only the standard library.

Run with:

    python3 scripts/changelog_test.py
"""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent / "changelog.py"
SPEC = importlib.util.spec_from_file_location("changelog", SCRIPT)
assert SPEC and SPEC.loader
changelog = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(changelog)

HEADER = """# Changelog

[English](CHANGELOG.md) | [简体中文](CHANGELOG.zh-CN.md)

Intro.

"""

SAMPLE = """{
  "en": {"added": ["A new feature."], "changed": [], "fixed": [],
         "removed": [], "security": []},
  "zh": {"added": ["新增一项功能。"], "changed": [], "fixed": [],
         "removed": [], "security": []}
}"""


class ValidateTests(unittest.TestCase):
    def test_aligned_payload_is_accepted(self):
        import json

        entries = changelog.validate(json.loads(SAMPLE))
        self.assertEqual(entries["en"]["added"], ["A new feature."])
        self.assertEqual(entries["zh"]["added"], ["新增一项功能。"])

    def test_mismatched_lengths_are_rejected(self):
        import json

        payload = json.loads(SAMPLE)
        payload["zh"]["added"] = []
        with self.assertRaises(SystemExit):
            changelog.validate(payload)

    def test_unknown_category_is_rejected(self):
        import json

        payload = json.loads(SAMPLE)
        payload["en"]["documented"] = []
        with self.assertRaises(SystemExit):
            changelog.validate(payload)

    def test_entries_are_normalized(self):
        import json

        payload = json.loads(SAMPLE)
        payload["en"]["added"] = ["-   Wrapped   entry. "]
        entries = changelog.validate(payload)
        self.assertEqual(entries["en"]["added"], ["Wrapped entry."])


class RenderTests(unittest.TestCase):
    def test_english_entries_wrap_at_80_columns(self):
        entries = {
            "en": {
                "added": [
                    "A long entry that keeps going so that the renderer has to "
                    "wrap it onto a second line without breaking any words."
                ],
                "changed": [],
                "fixed": [],
                "removed": [],
                "security": [],
            }
        }
        section = changelog.render_section("0.2.0", "2026-10-23", entries["en"], "en")
        self.assertIn("## [0.2.0] - 2026-10-23", section)
        self.assertIn("### Added", section)
        for line in section.splitlines():
            self.assertLessEqual(len(line), 80)

    def test_chinese_entries_stay_on_one_line(self):
        entries = {
            "zh": {
                "added": ["新增一项功能，并保持中英双语条目一一对应。"],
                "changed": [],
                "fixed": [],
                "removed": [],
                "security": [],
            }
        }
        section = changelog.render_section("0.2.0", "2026-10-23", entries["zh"], "zh")
        self.assertIn("### 新增", section)
        self.assertIn("- 新增一项功能，并保持中英双语条目一一对应。", section.splitlines())

    def test_notes_put_chinese_first_and_link_the_comparison(self):
        import json

        entries = changelog.validate(json.loads(SAMPLE))
        notes = changelog.render_notes("0.2.0", "v0.1.0", entries)
        self.assertLess(notes.index("### 新增"), notes.index("### Added"))
        self.assertIn(
            "https://github.com/quyansiyuanwang/docksnap/compare/v0.1.0...v0.2.0",
            notes,
        )


class MarkdownTests(unittest.TestCase):
    def test_unreleased_section_and_reference_are_removed(self):
        text = (
            HEADER
            + "## [Unreleased]\n\n### Added\n\n- Staged.\n\n"
            + "## [0.1.0] - 2026-10-16\n\n### Added\n\n- Old.\n\n"
            + "[0.1.0]: https://github.com/quyansiyuanwang/docksnap"
            "/releases/tag/v0.1.0\n"
        )
        cleaned = changelog.remove_unreleased(text)
        self.assertNotIn("[Unreleased]", cleaned)
        self.assertNotIn("Staged.", cleaned)
        self.assertIn("## [0.1.0] - 2026-10-16", cleaned)

    def test_link_reference_is_added_once(self):
        text = "[0.1.0]: https://example.com/0.1.0\n"
        once = changelog.add_link_reference(text, "0.2.0", "v0.1.0")
        twice = changelog.add_link_reference(once, "0.2.0", "v0.1.0")
        self.assertIn("[0.2.0]: https://github.com/quyansiyuanwang/docksnap"
                      "/compare/v0.1.0...v0.2.0", once)
        self.assertEqual(once, twice)
        self.assertLess(once.index("[0.2.0]"), once.index("[0.1.0]"))

    def test_section_is_inserted_after_the_header(self):
        import json

        entries = changelog.validate(json.loads(SAMPLE))
        section = changelog.render_section("0.2.0", "2026-10-23", entries["en"], "en")
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "CHANGELOG.md"
            path.write_text(
                HEADER + "## [0.1.0] - 2026-10-16\n\n### Added\n\n- Old.\n",
                encoding="utf-8",
            )
            self.assertTrue(
                changelog.insert_section(path, section, "0.2.0", "v0.1.0")
            )
            written = path.read_text(encoding="utf-8")
            self.assertLess(written.index("## [0.2.0]"), written.index("## [0.1.0]"))
            self.assertIn("[0.2.0]: https://github.com/", written)

    def test_force_replaces_an_existing_section(self):
        import json

        entries = changelog.validate(json.loads(SAMPLE))
        section = changelog.render_section(
            "0.2.0", "2026-10-23", entries["en"], "en"
        )
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "CHANGELOG.md"
            path.write_text(
                HEADER
                + "## [0.2.0] - 2026-10-23\n\n- Old text.\n\n"
                + "## [0.1.0] - 2026-10-16\n",
                encoding="utf-8",
            )
            self.assertTrue(
                changelog.insert_section(
                    path, section, "0.2.0", "v0.1.0", force=True
                )
            )
            written = path.read_text(encoding="utf-8")
            self.assertIn("A new feature.", written)
            self.assertNotIn("Old text.", written)
            self.assertEqual(written.count("## [0.2.0]"), 1)

    def test_existing_section_is_not_duplicated(self):
        import json

        entries = changelog.validate(json.loads(SAMPLE))
        section = changelog.render_section("0.2.0", "2026-10-23", entries["en"], "en")
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "CHANGELOG.md"
            path.write_text(
                HEADER + section + "\n## [0.1.0] - 2026-10-16\n",
                encoding="utf-8",
            )
            self.assertFalse(
                changelog.insert_section(path, section, "0.2.0", "v0.1.0")
            )


class TagTests(unittest.TestCase):
    def test_release_tags_are_parsed(self):
        self.assertEqual(
            changelog.version_and_tag("v0.2.0"), ("0.2.0", "v0.2.0")
        )
        self.assertEqual(
            changelog.version_and_tag("v1.0.0-beta.2"), ("1.0.0-beta.2", "v1.0.0-beta.2")
        )

    def test_invalid_tags_are_rejected(self):
        for tag in ("0.2.0", "v0.2", "v1.2.3.4", "release-v1.2.3"):
            with self.assertRaises(SystemExit, msg=tag):
                changelog.version_and_tag(tag)


if __name__ == "__main__":
    unittest.main()
