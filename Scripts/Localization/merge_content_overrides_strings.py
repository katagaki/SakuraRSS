#!/usr/bin/env python3
"""Merge per-key localization JSON files into Feeds.xcstrings.

Reads every *.json file under ./ContentOverrides/, each shaped like:

    {
      "key": "FeedEdit.Foo",
      "localizations": {"en": "Foo", "ja": "...", ...}
    }

For each entry, writes/updates the corresponding key in Feeds.xcstrings
with `extractionState = manual` and the localized stringUnits per language.

Strings themselves live in the JSON files; this script only structures them.
"""

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
XCSTRINGS_PATH = ROOT / "Shared" / "Strings" / "Feeds.xcstrings"
DATA_DIR = Path(__file__).resolve().parent / "ContentOverrides"


def load_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as fh:
        return json.load(fh)


def write_json(path: Path, payload: dict) -> None:
    # Match the existing Xcode xcstrings formatter: 2-space indent, ` : ` separator,
    # and trailing newline so the diff stays minimal.
    serialized = json.dumps(
        payload,
        ensure_ascii=False,
        indent=2,
        sort_keys=True,
        separators=(",", " : "),
    )
    with path.open("w", encoding="utf-8") as fh:
        fh.write(serialized)
        fh.write("\n")


def upsert_key(xcstrings: dict, key: str, language_values: dict) -> None:
    strings = xcstrings.setdefault("strings", {})
    entry = strings.setdefault(key, {})
    entry["extractionState"] = "manual"
    localizations = entry.setdefault("localizations", {})
    for language, value in language_values.items():
        localizations[language] = {
            "stringUnit": {
                "state": "translated",
                "value": value,
            }
        }


def main() -> int:
    if not XCSTRINGS_PATH.exists():
        print(f"Missing xcstrings file: {XCSTRINGS_PATH}", file=sys.stderr)
        return 1
    if not DATA_DIR.exists():
        print(f"Missing data dir: {DATA_DIR}", file=sys.stderr)
        return 1

    xcstrings = load_json(XCSTRINGS_PATH)

    for json_path in sorted(DATA_DIR.glob("*.json")):
        payload = load_json(json_path)
        key = payload["key"]
        language_values = payload["localizations"]
        upsert_key(xcstrings, key, language_values)
        print(f"  • {key}")

    write_json(XCSTRINGS_PATH, xcstrings)
    print(f"Updated {XCSTRINGS_PATH}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
