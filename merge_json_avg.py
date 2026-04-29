#!/usr/bin/env python3
"""Merge JSON files by averaging numeric values.

Rules:
- Supports any number of input files.
- Numeric leaves are averaged over all input files.
- Missing numeric values are treated as 0 in the average.
- Nested dictionaries are merged recursively.
- Non-numeric values are preserved when equal; otherwise all distinct values are kept.
"""

import argparse
import json
from pathlib import Path
from typing import Any


MISSING = object()


def is_number(value: Any) -> bool:
    """Return True for int/float values, but not bool."""
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def dedupe_preserve_order(values: list[Any]) -> list[Any]:
    """Deduplicate values while preserving input order."""
    unique: list[Any] = []
    for value in values:
        if value not in unique:
            unique.append(value)
    return unique


def merge_avg_many(values: list[Any]) -> Any:
    """Merge many values recursively by averaging numeric leaves."""
    total_inputs = len(values)
    non_missing = [value for value in values if value is not MISSING]

    if not non_missing:
        return None

    if all(isinstance(value, dict) for value in non_missing):
        dicts = non_missing
        all_keys: set[str] = set()
        for value in dicts:
            all_keys.update(value.keys())

        merged: dict[str, Any] = {}
        for key in sorted(all_keys):
            child_values = []
            for value in values:
                if isinstance(value, dict):
                    child_values.append(value.get(key, MISSING))
                else:
                    child_values.append(MISSING)
            merged[key] = merge_avg_many(child_values)
        return merged

    if all(is_number(value) for value in non_missing):
        return sum(non_missing) / total_inputs

    if all(value == non_missing[0] for value in non_missing):
        return non_missing[0]

    return dedupe_preserve_order(non_missing)


def load_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as fp:
        return json.load(fp)


def sort_desc_numeric(table: dict[str, Any]) -> dict[str, Any]:
    """Sort a dictionary by descending numeric values, then by key."""
    return dict(
        sorted(
            table.items(),
            key=lambda item: (0, -item[1], item[0])
            if is_number(item[1])
            else (1, 0, item[0]),
        )
    )


def sort_ngrams_sections(merged: Any) -> Any:
    """Sort top-level symbols, bigrams and trigrams sections in descending order."""
    if not isinstance(merged, dict):
        return merged

    for section in ("symbols", "bigrams", "trigrams"):
        value = merged.get(section)
        if isinstance(value, dict):
            merged[section] = sort_desc_numeric(value)
    return merged


def order_top_level_keys(merged: Any) -> Any:
    """Order top-level keys as corpus, symbols, bigrams, trigrams, then remaining keys."""
    if not isinstance(merged, dict):
        return merged

    ordered: dict[str, Any] = {}
    preferred_order = ["corpus", "symbols", "bigrams", "trigrams"]

    for key in preferred_order:
        if key in merged:
            ordered[key] = merged[key]

    for key, value in merged.items():
        if key not in ordered:
            ordered[key] = value

    return ordered


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Merge JSON files by averaging numeric values."
    )
    parser.add_argument(
        "json_files",
        type=Path,
        nargs="+",
        help="Paths to input JSON files (2 or more)",
    )
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        help="Write merged JSON to this file (defaults to stdout)",
    )
    args = parser.parse_args()

    if len(args.json_files) < 2:
        parser.error("Please provide at least 2 input JSON files.")

    data = [load_json(path) for path in args.json_files]

    merged = merge_avg_many(data)
    merged = sort_ngrams_sections(merged)
    merged = order_top_level_keys(merged)

    if args.output is None:
        print(json.dumps(merged, indent=4, ensure_ascii=False))
    else:
        with args.output.open("w", encoding="utf-8") as fp:
            json.dump(merged, fp, indent=4, ensure_ascii=False)
            fp.write("\n")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
