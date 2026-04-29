#!/usr/bin/env python3
"""Filter low-frequency bigrams and trigrams from a corpus JSON file."""

import argparse
import json
from pathlib import Path
from typing import Any


def load_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as fp:
        return json.load(fp)


def filter_section(data: dict[str, Any], section: str, threshold: float) -> None:
    """Remove entries from a top-level n-gram section below threshold."""
    value = data.get(section)
    if not isinstance(value, dict):
        return

    data[section] = {
        key: score for key, score in value.items() if isinstance(score, (int, float)) and score >= threshold
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Remove bigrams and trigrams whose value is below a threshold."
    )
    parser.add_argument("json_file", type=Path, help="Path to input JSON file")
    parser.add_argument(
        "threshold",
        type=float,
        help="Minimum value to keep in bigrams and trigrams",
    )
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        help="Write filtered JSON to this file (defaults to stdout)",
    )
    args = parser.parse_args()

    data = load_json(args.json_file)
    if not isinstance(data, dict):
        parser.error("Input JSON must be a top-level object.")

    filter_section(data, "bigrams", args.threshold)
    filter_section(data, "trigrams", args.threshold/2)

    if args.output is None:
        print(json.dumps(data, indent=4, ensure_ascii=False))
    else:
        with args.output.open("w", encoding="utf-8") as fp:
            json.dump(data, fp, indent=4, ensure_ascii=False)
            fp.write("\n")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())