#!/usr/bin/env python3
"""Verify exact Korean text, NFC normalization, and absence of jamo."""

from __future__ import annotations

import argparse
import json
import unicodedata
import xml.etree.ElementTree as ET
from pathlib import Path

JAMO_RANGES = (
    (0x1100, 0x11FF, "Hangul Jamo"),
    (0x3130, 0x318F, "Hangul Compatibility Jamo"),
    (0xA960, 0xA97F, "Hangul Jamo Extended-A"),
    (0xD7B0, 0xD7FF, "Hangul Jamo Extended-B"),
)


def codepoints(text: str) -> list[str]:
    return [f"U+{ord(char):04X}" for char in text]


def find_jamo(text: str) -> list[dict[str, str]]:
    found: list[dict[str, str]] = []
    for char in text:
        value = ord(char)
        for start, end, block in JAMO_RANGES:
            if start <= value <= end:
                found.append(
                    {
                        "character": char,
                        "codepoint": f"U+{value:04X}",
                        "block": block,
                    }
                )
                break
    return found


def verify(
    observed: str, expected: str, allow_intermediate_jamo: bool = False
) -> dict[str, object]:
    jamo = find_jamo(observed)
    reasons: list[str] = []
    if observed != expected:
        reasons.append("exact mismatch")
    if unicodedata.normalize("NFC", observed) != observed:
        reasons.append("observed text is not NFC")
    if jamo and not allow_intermediate_jamo:
        reasons.append("observed text contains jamo")
    return {
        "ok": not reasons,
        "observed": observed,
        "expected": expected,
        "observed_codepoints": codepoints(observed),
        "expected_codepoints": codepoints(expected),
        "is_nfc": unicodedata.normalize("NFC", observed) == observed,
        "jamo": jamo,
        "allow_intermediate_jamo": allow_intermediate_jamo,
        "reasons": reasons,
    }


def select_xml_text(xml_path: Path, resource_id: str | None) -> str:
    root = ET.parse(xml_path).getroot()
    nodes = list(root.iter("node"))
    if resource_id:
        matches = [
            node for node in nodes if node.attrib.get("resource-id") == resource_id
        ]
    else:
        matches = [
            node
            for node in nodes
            if node.attrib.get("focused") == "true"
            and (
                node.attrib.get("class") == "android.widget.EditText"
                or node.attrib.get("editable") == "true"
            )
        ]
    if len(matches) != 1:
        raise ValueError(f"expected one target node, found {len(matches)}")
    return matches[0].attrib.get("text", "")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)

    text_parser = subparsers.add_parser("text")
    text_parser.add_argument("--observed", required=True)
    text_parser.add_argument("--expected", required=True)
    text_parser.add_argument("--allow-intermediate-jamo", action="store_true")

    xml_parser = subparsers.add_parser("xml")
    xml_parser.add_argument("--xml", type=Path, required=True)
    xml_parser.add_argument("--expected", required=True)
    xml_parser.add_argument("--resource-id")
    xml_parser.add_argument("--allow-intermediate-jamo", action="store_true")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    try:
        observed = (
            args.observed
            if args.command == "text"
            else select_xml_text(args.xml, args.resource_id)
        )
    except (ET.ParseError, OSError, ValueError) as error:
        print(json.dumps({"ok": False, "error": str(error)}, ensure_ascii=False))
        return 2

    result = verify(observed, args.expected, args.allow_intermediate_jamo)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
