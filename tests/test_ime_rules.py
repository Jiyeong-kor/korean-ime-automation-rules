from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


dubeolsik = load_module("dubeolsik_plan", ROOT / "scripts" / "dubeolsik_plan.py")
verifier = load_module("verify_hangul", ROOT / "scripts" / "verify_hangul.py")


class DubeolsikPlanTest(unittest.TestCase):
    def test_suseok_plan_separates_logical_and_qwerty_keys(self) -> None:
        plan = dubeolsik.build_plan("수석")
        self.assertEqual(plan["logical_keys"], ["ㅅ", "ㅜ", "ㅅ", "ㅓ", "ㄱ"])
        self.assertEqual(plan["qwerty_keys"], ["t", "n", "t", "j", "r"])
        self.assertEqual(plan["touch_keys"], ["ㅅ", "ㅜ", "ㅅ", "ㅓ", "ㄱ"])
        self.assertIsNone(plan["coordinate_mapping"])

    def test_compound_vowel_is_split(self) -> None:
        plan = dubeolsik.build_plan("괄")
        self.assertEqual(plan["logical_keys"], ["ㄱ", "ㅗ", "ㅏ", "ㄹ"])

    def test_shifted_touch_key_is_explicit(self) -> None:
        plan = dubeolsik.build_plan("까")
        self.assertEqual(plan["logical_keys"], ["ㄲ", "ㅏ"])
        self.assertEqual(plan["touch_keys"], ["shift", "ㄱ", "ㅏ"])


class HangulVerifierTest(unittest.TestCase):
    def test_nfc_syllables_pass(self) -> None:
        result = verifier.verify("수석", "수석")
        self.assertTrue(result["ok"])
        self.assertEqual(result["observed_codepoints"], ["U+C218", "U+C11D"])

    def test_compatibility_jamo_fail(self) -> None:
        result = verifier.verify("ㅅㅜㅅㅓㄱ", "수석")
        self.assertFalse(result["ok"])
        self.assertIn("observed text contains jamo", result["reasons"])

    def test_nfd_fail_default_policy(self) -> None:
        result = verifier.verify("수석", "수석")
        self.assertFalse(result["ok"])
        self.assertIn("observed text is not NFC", result["reasons"])

    def test_intermediate_jamo_can_be_checked_explicitly(self) -> None:
        result = verifier.verify("ㅅ", "ㅅ", allow_intermediate_jamo=True)
        self.assertTrue(result["ok"])

    def test_xml_target_is_selected_by_resource_id(self) -> None:
        observed = verifier.select_xml_text(
            ROOT / "tests" / "fixtures" / "success.xml",
            "com.example:id/query",
        )
        self.assertEqual(observed, "수석")


if __name__ == "__main__":
    unittest.main()
