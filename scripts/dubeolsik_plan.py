#!/usr/bin/env python3
"""Convert modern precomposed Hangul syllables to Dubeolsik key plans."""

from __future__ import annotations

import argparse
import json
import sys
import unicodedata

L_KEYS = (
    ("ㄱ",),
    ("ㄲ",),
    ("ㄴ",),
    ("ㄷ",),
    ("ㄸ",),
    ("ㄹ",),
    ("ㅁ",),
    ("ㅂ",),
    ("ㅃ",),
    ("ㅅ",),
    ("ㅆ",),
    ("ㅇ",),
    ("ㅈ",),
    ("ㅉ",),
    ("ㅊ",),
    ("ㅋ",),
    ("ㅌ",),
    ("ㅍ",),
    ("ㅎ",),
)

V_KEYS = (
    ("ㅏ",),
    ("ㅐ",),
    ("ㅑ",),
    ("ㅒ",),
    ("ㅓ",),
    ("ㅔ",),
    ("ㅕ",),
    ("ㅖ",),
    ("ㅗ",),
    ("ㅗ", "ㅏ"),
    ("ㅗ", "ㅐ"),
    ("ㅗ", "ㅣ"),
    ("ㅛ",),
    ("ㅜ",),
    ("ㅜ", "ㅓ"),
    ("ㅜ", "ㅔ"),
    ("ㅜ", "ㅣ"),
    ("ㅠ",),
    ("ㅡ",),
    ("ㅡ", "ㅣ"),
    ("ㅣ",),
)

T_KEYS = (
    (),
    ("ㄱ",),
    ("ㄲ",),
    ("ㄱ", "ㅅ"),
    ("ㄴ",),
    ("ㄴ", "ㅈ"),
    ("ㄴ", "ㅎ"),
    ("ㄷ",),
    ("ㄹ",),
    ("ㄹ", "ㄱ"),
    ("ㄹ", "ㅁ"),
    ("ㄹ", "ㅂ"),
    ("ㄹ", "ㅅ"),
    ("ㄹ", "ㅌ"),
    ("ㄹ", "ㅍ"),
    ("ㄹ", "ㅎ"),
    ("ㅁ",),
    ("ㅂ",),
    ("ㅂ", "ㅅ"),
    ("ㅅ",),
    ("ㅆ",),
    ("ㅇ",),
    ("ㅈ",),
    ("ㅊ",),
    ("ㅋ",),
    ("ㅌ",),
    ("ㅍ",),
    ("ㅎ",),
)

QWERTY = {
    "ㄱ": ("r",),
    "ㄲ": ("shift+r",),
    "ㄴ": ("s",),
    "ㄷ": ("e",),
    "ㄸ": ("shift+e",),
    "ㄹ": ("f",),
    "ㅁ": ("a",),
    "ㅂ": ("q",),
    "ㅃ": ("shift+q",),
    "ㅅ": ("t",),
    "ㅆ": ("shift+t",),
    "ㅇ": ("d",),
    "ㅈ": ("w",),
    "ㅉ": ("shift+w",),
    "ㅊ": ("c",),
    "ㅋ": ("z",),
    "ㅌ": ("x",),
    "ㅍ": ("v",),
    "ㅎ": ("g",),
    "ㅏ": ("k",),
    "ㅐ": ("o",),
    "ㅑ": ("i",),
    "ㅒ": ("shift+o",),
    "ㅓ": ("j",),
    "ㅔ": ("p",),
    "ㅕ": ("u",),
    "ㅖ": ("shift+p",),
    "ㅗ": ("h",),
    "ㅛ": ("y",),
    "ㅜ": ("n",),
    "ㅠ": ("b",),
    "ㅡ": ("m",),
    "ㅣ": ("l",),
}

TOUCH_KEYS = {key: (key,) for key in QWERTY}
TOUCH_KEYS.update(
    {
        "ㄲ": ("shift", "ㄱ"),
        "ㄸ": ("shift", "ㄷ"),
        "ㅃ": ("shift", "ㅂ"),
        "ㅆ": ("shift", "ㅅ"),
        "ㅉ": ("shift", "ㅈ"),
        "ㅒ": ("shift", "ㅐ"),
        "ㅖ": ("shift", "ㅔ"),
    }
)


def decompose_syllable(char: str) -> tuple[str, ...]:
    codepoint = ord(char)
    if not 0xAC00 <= codepoint <= 0xD7A3:
        raise ValueError(f"not a modern precomposed Hangul syllable: {char!r}")
    index = codepoint - 0xAC00
    leading = index // 588
    vowel = (index % 588) // 28
    trailing = index % 28
    return L_KEYS[leading] + V_KEYS[vowel] + T_KEYS[trailing]


def build_plan(text: str) -> dict[str, object]:
    if unicodedata.normalize("NFC", text) != text:
        raise ValueError("target must already be NFC")

    logical_keys: list[str] = []
    syllables: list[dict[str, object]] = []
    for char in text:
        if char.isspace():
            keys = ("space",)
        elif 0xAC00 <= ord(char) <= 0xD7A3:
            keys = decompose_syllable(char)
        else:
            raise ValueError(f"unsupported character: {char!r}")
        logical_keys.extend(keys)
        syllables.append({"text": char, "keys": list(keys)})

    qwerty_keys: list[str] = []
    touch_keys: list[str] = []
    for key in logical_keys:
        qwerty_keys.extend(("space",) if key == "space" else QWERTY[key])
        touch_keys.extend(("space",) if key == "space" else TOUCH_KEYS[key])

    return {
        "target": text,
        "normalization": "NFC",
        "syllables": syllables,
        "logical_keys": logical_keys,
        "qwerty_keys": qwerty_keys,
        "touch_keys": touch_keys,
        "coordinate_mapping": None,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("text")
    args = parser.parse_args()
    try:
        plan = build_plan(args.text)
    except ValueError as error:
        print(str(error), file=sys.stderr)
        return 2
    print(json.dumps(plan, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
