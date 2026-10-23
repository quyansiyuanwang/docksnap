#!/usr/bin/env python3
"""Generate the bilingual changelog section for a release from git history.

The release workflow runs this script for every ``v*`` tag:

1. collect the conventional commits between the previous tag and the new tag,
2. ask an OpenAI-compatible chat completion endpoint for the English and
   Simplified Chinese entries,
3. insert one Keep a Changelog section into ``CHANGELOG.md`` and
   ``CHANGELOG.zh-CN.md`` and refresh the link references.

Only the Python standard library is used.

Environment:

``CHANGELOG_LLM_BASE_URL``  OpenAI-compatible API base URL, for example
                            ``https://api.example.com/v1``. A full
                            ``/chat/completions`` URL is accepted too.
``CHANGELOG_LLM_API_KEY``   API key sent as a bearer token.
``CHANGELOG_LLM_MODEL``     Model name, for example ``gpt-4.1-mini``.

Usage:

    python3 scripts/changelog.py --tag v0.2.0 --write \
        --notes-out "$RUNNER_TEMP/release-notes.md"

For local checks without network access, pass ``--response responses.json``
with a payload shaped like the expected model output.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import textwrap
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Dict, List, NoReturn, Optional, Sequence, Tuple

REPO = "quyansiyuanwang/docksnap"
ROOT = Path(__file__).resolve().parent.parent

CATEGORIES = ("added", "changed", "fixed", "removed", "security")

HEADINGS: Dict[str, Dict[str, str]] = {
    "en": {
        "added": "Added",
        "changed": "Changed",
        "fixed": "Fixed",
        "removed": "Removed",
        "security": "Security",
    },
    "zh": {
        "added": "新增",
        "changed": "改进",
        "fixed": "修复",
        "removed": "移除",
        "security": "安全",
    },
}

CHANGELOG_FILES = {
    "en": ROOT / "CHANGELOG.md",
    "zh": ROOT / "CHANGELOG.zh-CN.md",
}

TAG_PATTERN = re.compile(r"^v(\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?)$")

# Commits that only maintain the changelog or cut a release must never feed the
# next changelog. Everything else is left to the model, which is told to drop
# build, CI, test and documentation-only work.
SKIP_SUBJECT = re.compile(
    r"^(?:docs|chore|ci|build|test|style)(?:\([^)]*\))?:\s*"
    r"(?:changelog|release|bump|version)\b",
    re.IGNORECASE,
)

SYSTEM_PROMPT = """\
You write the changelog for DockSnap, a macOS menu bar utility that saves and \
restores window frames and aligns the left edge with the Dock. It is written in \
Swift with Swift Package Manager, uses the Accessibility API to move windows and \
Carbon's RegisterEventHotKey for global hot keys.

You receive the commits merged between the previous release and the new release. \
Turn them into the user-facing changelog entries for the new release, in English \
and in Simplified Chinese.

Rules:

- Keep user-visible changes only: new behaviour, changed behaviour, fixes, \
removed behaviour and security fixes. Drop build, CI, test, style, formatting and \
documentation-only commits, release chores and merge commits. Documentation \
changes are kept only when they correct instructions users rely on.
- Merge commits that describe the same change into one entry. Describe the \
outcome for the user, not the implementation detail or the file that changed.
- Use the Keep a Changelog categories: added, changed, fixed, removed, security. \
Map commit prefixes as follows: feat -> added, fix -> fixed, \
perf/refactor/revert -> changed. Security fixes go to security. Leave a category \
empty when nothing belongs there.
- Each entry is one sentence, sentence case, no trailing ellipsis, no emoji, no \
commit hash, no author name, no issue or pull request reference, no markdown.
- Do not repeat entries that already exist in the previous release section you \
are given.
- English and Simplified Chinese must carry the same entries in the same order: \
for every category, both arrays have the same length and the same meaning.
- Chinese entries use full-width punctuation, end with a full stop, and keep \
product and API names in English (DockSnap, Dock, Accessibility API, Carbon, \
SwiftPM, CLI).
- Do not wrap English entries yourself; the script wraps them to 80 columns.

Respond with a single JSON object and nothing else, with this exact shape:

{"en": {"added": [], "changed": [], "fixed": [], "removed": [], "security": []},
 "zh": {"added": [], "changed": [], "fixed": [], "removed": [], "security": []}}

Every category must be present in both objects. Empty arrays are allowed, but a \
release with no user-visible change at all should return every array empty.
"""


def git(*args: str, check: bool = True) -> str:
    result = subprocess.run(
        ("git", *args), cwd=ROOT, text=True, capture_output=True
    )
    if check and result.returncode != 0:
        raise SystemExit(
            "git {} failed:\n{}".format(" ".join(args), result.stderr.strip())
        )
    return result.stdout.strip()


def fail(message: str) -> "NoReturn":
    raise SystemExit(message)


def version_and_tag(raw_tag: str) -> Tuple[str, str]:
    match = TAG_PATTERN.match(raw_tag)
    if not match:
        fail(
            "Unsupported tag {!r}; expected vMAJOR.MINOR.PATCH.".format(raw_tag)
        )
    return match.group(1), raw_tag


def previous_tag(tag: str) -> Optional[str]:
    result = subprocess.run(
        ("git", "describe", "--tags", "--match", "v*", "--abbrev=0", tag + "^"),
        cwd=ROOT,
        text=True,
        capture_output=True,
    )
    if result.returncode != 0:
        return None
    return result.stdout.strip() or None


def tag_date(tag: str) -> str:
    return git("log", "-1", "--format=%cs", tag)


def collect_commits(previous: Optional[str], tag: str) -> List[Dict[str, str]]:
    revision = "{}..{}".format(previous, tag) if previous else tag
    raw = git(
        "log",
        "--no-merges",
        "--format=%H%x1f%s%x1f%b%x1e",
        revision,
    )
    commits: List[Dict[str, str]] = []
    for record in raw.split("\x1e"):
        record = record.strip("\n")
        if not record.strip():
            continue
        fields = record.split("\x1f")
        if len(fields) < 2:
            continue
        sha = fields[0].strip()
        subject = fields[1].strip()
        body = fields[2].strip() if len(fields) > 2 else ""
        if not subject:
            continue
        lowered = subject.lower()
        if SKIP_SUBJECT.match(subject) or "[skip changelog]" in lowered:
            continue
        commits.append(
            {"sha": sha[:7], "subject": subject, "body": body[:600]}
        )
    commits.reverse()  # oldest first, the order a changelog reads in
    return commits


def latest_release_excerpt() -> str:
    text = CHANGELOG_FILES["en"].read_text(encoding="utf-8")
    match = re.search(r"^## \[.*?(?=^## \[|\Z)", text, re.M | re.S)
    if not match:
        return "(no previous release)"
    return match.group(0).strip()[:1500]


def build_user_prompt(
    tag: str, version: str, previous: Optional[str], commits: Sequence[Dict[str, str]]
) -> str:
    lines = [
        "Previous release tag: {}".format(previous or "(none, this is the first release)"),
        "New release tag: {}".format(tag),
        "New version: {}".format(version),
        "",
        "Previous release section, for tone and for avoiding duplicates:",
        "```markdown",
        latest_release_excerpt(),
        "```",
        "",
        "Commits merged since the previous release (oldest first):",
    ]
    for commit in commits:
        lines.append("- {} {}".format(commit["sha"], commit["subject"]))
        if commit["body"]:
            for body_line in commit["body"].splitlines():
                body_line = body_line.strip()
                if body_line:
                    lines.append("    " + body_line)
    return "\n".join(lines)


def strip_code_fence(text: str) -> str:
    text = text.strip()
    if text.startswith("```"):
        text = re.sub(r"^```[A-Za-z0-9_-]*\s*", "", text)
        text = re.sub(r"\s*```$", "", text)
    return text.strip()


def parse_response(content: str) -> Dict[str, Dict[str, List[str]]]:
    try:
        return json.loads(strip_code_fence(content))
    except json.JSONDecodeError:
        match = re.search(r"\{.*\}", strip_code_fence(content), re.S)
        if not match:
            fail("The model did not return JSON:\n" + content[:800])
        try:
            return json.loads(match.group(0))
        except json.JSONDecodeError as error:
            fail("The model returned invalid JSON: {}".format(error))


def clean_entry(entry: str) -> str:
    entry = re.sub(r"^[-*]\s+", "", entry.strip())
    return re.sub(r"\s+", " ", entry).strip()


def validate(
    payload: Dict[str, Dict[str, List[str]]]
) -> Dict[str, Dict[str, List[str]]]:
    if not isinstance(payload, dict) or set(payload) != {"en", "zh"}:
        fail("The model output must contain exactly the 'en' and 'zh' objects.")
    cleaned: Dict[str, Dict[str, List[str]]] = {}
    for language in ("en", "zh"):
        block = payload[language]
        if not isinstance(block, dict):
            fail("The '{}' value must be an object.".format(language))
        unknown = set(block) - set(CATEGORIES)
        if unknown:
            fail(
                "Unknown {} categories: {}.".format(
                    language, ", ".join(sorted(unknown))
                )
            )
        cleaned[language] = {}
        for category in CATEGORIES:
            entries = block.get(category)
            if not isinstance(entries, list):
                fail(
                    "The '{}' / '{}' value must be an array.".format(
                        language, category
                    )
                )
            values = []
            for entry in entries:
                if not isinstance(entry, str) or not entry.strip():
                    fail("Changelog entries must be non-empty strings.")
                values.append(clean_entry(entry))
            cleaned[language][category] = values
    for category in CATEGORIES:
        if len(cleaned["en"][category]) != len(cleaned["zh"][category]):
            fail(
                "The en and zh '{}' lists differ in length ({} vs {}); the "
                "bilingual sections must stay aligned.".format(
                    category,
                    len(cleaned["en"][category]),
                    len(cleaned["zh"][category]),
                )
            )
    return cleaned


def post_completion(url: str, api_key: str, payload: Dict[str, object]) -> str:
    body = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=body,
        method="POST",
        headers={
            "Content-Type": "application/json",
            "Authorization": "Bearer " + api_key,
        },
    )
    with urllib.request.urlopen(request, timeout=240) as response:
        data = json.loads(response.read().decode("utf-8"))
    try:
        content = data["choices"][0]["message"]["content"]
    except (KeyError, IndexError, TypeError):
        fail("Unexpected model response:\n" + json.dumps(data)[:800])
    if not isinstance(content, str):
        fail("The model returned a non-text completion.")
    return content


def request_entries(user_prompt: str) -> Dict[str, Dict[str, List[str]]]:
    base_url = os.environ.get("CHANGELOG_LLM_BASE_URL", "").strip().rstrip("/")
    api_key = os.environ.get("CHANGELOG_LLM_API_KEY", "").strip()
    model = os.environ.get("CHANGELOG_LLM_MODEL", "").strip()
    missing = [
        name
        for name, value in (
            ("CHANGELOG_LLM_BASE_URL", base_url),
            ("CHANGELOG_LLM_API_KEY", api_key),
            ("CHANGELOG_LLM_MODEL", model),
        )
        if not value
    ]
    if missing:
        fail("Missing environment variables: " + ", ".join(missing))

    url = (
        base_url
        if base_url.endswith("/chat/completions")
        else base_url + "/chat/completions"
    )
    payload: Dict[str, object] = {
        "model": model,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": user_prompt},
        ],
        "temperature": 0.2,
        "response_format": {"type": "json_object"},
    }

    last_error = ""
    for attempt in range(1, 4):
        try:
            return parse_response(post_completion(url, api_key, payload))
        except urllib.error.HTTPError as error:
            detail = error.read().decode("utf-8", "replace")[:600]
            if (
                error.code == 400
                and "response_format" in detail
                and "response_format" in payload
            ):
                # Some OpenAI-compatible providers reject JSON mode.
                payload.pop("response_format")
                continue
            last_error = "HTTP {}: {}".format(error.code, detail)
            if error.code in (429, 500, 502, 503, 504):
                time.sleep(5 * attempt)
                continue
            fail("The changelog request failed. " + last_error)
        except (urllib.error.URLError, TimeoutError, OSError) as error:
            last_error = str(error)
            time.sleep(5 * attempt)
    fail("The changelog request failed after three attempts. " + last_error)


def render_section(
    version: str, date: str, entries: Dict[str, List[str]], language: str
) -> str:
    lines = ["## [{}] - {}".format(version, date), ""]
    for category in CATEGORIES:
        values = entries[category]
        if not values:
            continue
        lines.append("### " + HEADINGS[language][category])
        lines.append("")
        for value in values:
            if language == "en":
                lines.extend(
                    textwrap.wrap(
                        value,
                        width=80,
                        initial_indent="- ",
                        subsequent_indent="  ",
                        break_long_words=False,
                        break_on_hyphens=False,
                    )
                )
            else:
                lines.append("- " + value)
        lines.append("")
    return "\n".join(lines).rstrip("\n") + "\n"


def render_notes(
    version: str, previous: Optional[str], entries: Dict[str, List[str]]
) -> str:
    parts: List[str] = []
    for language in ("zh", "en"):
        for category in CATEGORIES:
            values = entries[language][category]
            if not values:
                continue
            parts.append("### " + HEADINGS[language][category])
            parts.append("")
            for value in values:
                parts.append("- " + value)
            parts.append("")
    if previous:
        compare = "https://github.com/{}/compare/{}...v{}".format(
            REPO, previous, version
        )
        parts.append(
            "**完整变更 / Full Changelog**: [{}...v{}]({})".format(
                previous, version, compare
            )
        )
    return "\n".join(parts).strip() + "\n"


def remove_unreleased(text: str) -> str:
    text = re.sub(
        r"^## \[(?:Unreleased|未发布)\][^\n]*\n.*?(?=^## \[|\Z)",
        "",
        text,
        flags=re.M | re.S,
    )
    text = re.sub(r"^\[(?:Unreleased|未发布)\]:.*\n?", "", text, flags=re.M)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text


def add_link_reference(text: str, version: str, previous: Optional[str]) -> str:
    if re.search(r"^\[{}\]:".format(re.escape(version)), text, re.M):
        return text
    if previous:
        url = "https://github.com/{}/compare/{}...v{}".format(
            REPO, previous, version
        )
    else:
        url = "https://github.com/{}/releases/tag/v{}".format(REPO, version)
    reference = "[{}]: {}".format(version, url)
    match = re.search(r"^\[[^\]]+\]: https?://", text, re.M)
    if match:
        return text[: match.start()] + reference + "\n" + text[match.start() :]
    return text.rstrip("\n") + "\n\n" + reference + "\n"


def insert_section(
    path: Path,
    section: str,
    version: str,
    previous: Optional[str],
    force: bool = False,
) -> bool:
    original = path.read_text(encoding="utf-8")
    text = remove_unreleased(original)
    exists = re.search(r"^## \[{}\]".format(re.escape(version)), text, re.M)
    if exists:
        if not force:
            if text != original:
                path.write_text(text, encoding="utf-8")
            return False
        text = re.sub(
            r"^## \[{}\] - [^\n]*\n.*?(?=^## \[|\Z)".format(re.escape(version)),
            "",
            text,
            flags=re.M | re.S,
        )
    match = re.search(r"^## \[", text, re.M)
    if match:
        head = text[: match.start()].rstrip("\n")
        tail = text[match.start() :]
        text = head + "\n\n" + section + "\n" + tail
    else:
        text = text.rstrip("\n") + "\n\n" + section
    text = add_link_reference(text, version, previous)
    path.write_text(text, encoding="utf-8")
    return True


def file_has_section(path: Path, version: str) -> bool:
    return bool(
        re.search(
            r"^## \[{}\]".format(re.escape(version)),
            path.read_text(encoding="utf-8"),
            re.M,
        )
    )


def existing_section(version: str) -> Optional[str]:
    text = CHANGELOG_FILES["en"].read_text(encoding="utf-8")
    match = re.search(
        r"^## \[{}\] - [^\n]*\n.*?(?=^## \[|\Z)".format(re.escape(version)),
        text,
        re.M | re.S,
    )
    if not match:
        return None
    return match.group(0).strip("\n")


def extract_body(section: str) -> str:
    lines = section.splitlines()
    if lines and lines[0].startswith("## ["):
        lines = lines[1:]
    return "\n".join(lines).strip()


def load_response(path: Path) -> Dict[str, Dict[str, List[str]]]:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        fail("Cannot read the --response payload: {}".format(error))


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag", required=True, help="release tag, for example v0.2.0")
    parser.add_argument(
        "--write", action="store_true", help="update the changelog files"
    )
    parser.add_argument(
        "--notes-out", type=Path, help="write GitHub release notes to this path"
    )
    parser.add_argument(
        "--response",
        type=Path,
        help="read the model output from this JSON file instead of the API",
    )
    parser.add_argument(
        "--force", action="store_true", help="regenerate an existing version section"
    )
    parser.add_argument(
        "--show-prompt", action="store_true", help="print the prompt and exit"
    )
    args = parser.parse_args(argv)

    version, tag = version_and_tag(args.tag)
    if not git("rev-parse", "--verify", "refs/tags/" + tag, check=False):
        fail("Tag {} does not exist locally; run git fetch --tags first.".format(tag))

    previous = previous_tag(tag)
    date = tag_date(tag)

    existing = existing_section(version)
    both_present = existing is not None and file_has_section(
        CHANGELOG_FILES["zh"], version
    )
    if both_present and not args.force and not args.show_prompt:
        print(
            "CHANGELOG already has a section for {}; leaving it untouched.".format(
                version
            )
        )
        if args.notes_out:
            zh_text = CHANGELOG_FILES["zh"].read_text(encoding="utf-8")
            zh_match = re.search(
                r"^## \[{}\] - [^\n]*\n.*?(?=^## \[|\Z)".format(
                    re.escape(version)
                ),
                zh_text,
                re.M | re.S,
            )
            notes = []
            if zh_match:
                notes.append("### 中文\n\n" + extract_body(zh_match.group(0)))
            notes.append("### English\n\n" + extract_body(existing))
            args.notes_out.write_text(
                "\n\n".join(notes) + "\n", encoding="utf-8"
            )
        return 0

    commits = collect_commits(previous, tag)
    if not commits:
        fail(
            "No commits between {} and {}; nothing to generate.".format(
                previous or "the repository root", tag
            )
        )
    print(
        "Generating the {} changelog from {} commits ({}..{}).".format(
            version, len(commits), previous or "root", tag
        )
    )

    user_prompt = build_user_prompt(tag, version, previous, commits)
    if args.show_prompt:
        print("\n--- SYSTEM ---\n" + SYSTEM_PROMPT)
        print("\n--- USER ---\n" + user_prompt)
        return 0

    if args.response:
        entries = validate(load_response(args.response))
    else:
        entries = validate(request_entries(user_prompt))

    written = False
    for language in ("en", "zh"):
        section = render_section(version, date, entries[language], language)
        if args.write:
            written = (
                insert_section(
                    CHANGELOG_FILES[language],
                    section,
                    version,
                    previous,
                    force=args.force or not both_present,
                )
                or written
            )
        else:
            print("\n--- {} ---\n{}".format(CHANGELOG_FILES[language].name, section))

    if args.notes_out:
        args.notes_out.write_text(
            render_notes(version, previous, entries), encoding="utf-8"
        )

    if args.write:
        if written:
            print("Updated CHANGELOG.md and CHANGELOG.zh-CN.md for {}.".format(version))
        else:
            print("Both changelog files already contain {}.".format(version))
    return 0


if __name__ == "__main__":
    sys.exit(main())
