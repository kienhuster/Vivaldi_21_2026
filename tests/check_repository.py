"""Repository and generated-script checks. These are NOT HFSS CAD validation.

python3 tests/check_repository.py [directory-containing-generated-vbs]
Only stdlib is required. Optional script checks inspect actual generated outputs.
"""
from pathlib import Path
import hashlib
import re
import subprocess
import sys
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SCRIPT_ROOT = Path(sys.argv.pop(1)) if len(sys.argv) > 1 else None
REFERENCES = (
    "17_10_2026_vivaldi.aedt",
    "Phan_tich_chi_tiet_Vivaldi_dual_pol_17_10_2026.md",
    "Standard_Vivaldi_GUI.m",
    "hfss-api-master.zip",
)


def code_without_strings(line):
    """Strip VB string literals, honoring doubled quotes and apostrophe comments."""
    out, index = [], 0
    while index < len(line):
        char = line[index]
        if char == "'":
            break
        if char != '"':
            out.append(char)
            index += 1
            continue
        index += 1
        while index < len(line):
            if line[index] == '"':
                if index + 1 < len(line) and line[index + 1] == '"':
                    index += 2
                    continue
                index += 1
                break
            index += 1
        else:
            raise ValueError("Unclosed VBScript string")
        out.append('""')
    return "".join(out)


class RepositoryChecks(unittest.TestCase):
    def test_reference_files_unchanged(self):
        for name in REFERENCES:
            original = subprocess.check_output(
                ["git", "show", f"b47f45aab78e93aea100ea754edd049cd0ed8e66:{name}"], cwd=ROOT
            )
            self.assertEqual(hashlib.sha256(original).digest(),
                             hashlib.sha256((ROOT / name).read_bytes()).digest(), name)

    def test_vendor_matches_uploaded_archive(self):
        expected = set()
        with zipfile.ZipFile(ROOT / "hfss-api-master.zip") as archive:
            self.assertIsNone(archive.testzip())
            for entry in archive.infolist():
                if entry.is_dir():
                    continue
                relative = Path(entry.filename).relative_to("hfss-api-master")
                expected.add(relative)
                self.assertEqual(archive.read(entry),
                                 (ROOT / "third_party/hfss-api" / relative).read_bytes(), str(relative))
        actual = {path.relative_to(ROOT / "third_party/hfss-api")
                  for path in (ROOT / "third_party/hfss-api").rglob("*") if path.is_file()}
        self.assertEqual(actual, expected)

    def test_model_evidence(self):
        model = (ROOT / REFERENCES[0]).read_bytes()
        self.assertEqual(hashlib.sha256(model).hexdigest(),
                         "631820b2c07f457fd22f5cdab2aeae15694788c869629935460b2cefda1ba619")
        text = model.decode("utf-8")
        for evidence in ["dual_pol_vivaldi_patch_Wflare_20", "BothSides=true",
                         "AngleStr='-90deg'", "NumClones='2'", "Type='Discrete'"]:
            self.assertIn(evidence, text)

    def test_four_application_files(self):
        names = {p.name for p in ROOT.glob("Vivaldi_*.m")}
        self.assertEqual(names, {"Vivaldi_GUI.m", "Vivaldi_Calculation.m",
                                "Vivaldi_HFSS_Builder.m", "Vivaldi_HFSS_Simulation.m"})
        for name in names:
            source = (ROOT / name).read_text(encoding="utf-8")
            self.assertNotRegex(source, r"(?i)\b(actxserver|actxGetRunningServer|restoredefaultpath|savepath)\s*\(")

    @unittest.skipUnless(SCRIPT_ROOT, "Pass a generated-script directory for lexical checks")
    def test_generated_vbs_structure(self):
        paths = list(SCRIPT_ROOT.rglob("*.vbs"))
        self.assertGreaterEqual(len(paths), 3, "Generate builder, simulation and probe first")
        for path in paths:
            with self.subTest(script=path.name):
                raw = path.read_bytes()
                self.assertTrue(raw.isascii(), "VBScript must be ASCII, without a BOM")
                depth, block_stack, statement = 0, [], ""
                scopes, declared = [], set()
                for number, physical in enumerate(raw.decode("ascii").splitlines(), 1):
                    self.assertLess(len(physical), 1023, f"Line too long at {number}")
                    code = code_without_strings(physical).strip()
                    for char in code:
                        depth += (char == "(") - (char == ")")
                        self.assertGreaterEqual(depth, 0, f"Closing parenthesis at {number}")
                    if code.endswith("_"):
                        statement += code[:-1] + " "
                        continue
                    code = (statement + code).strip()
                    statement = ""
                    lower = code.lower()
                    if re.match(r"^(sub|function)\b", lower):
                        self.assertFalse(scopes, f"Nested VB procedure at {number}")
                        scopes.append(lower.split("(")[0])
                        declared = set()
                        block_stack.append(lower.split()[0])
                    elif lower.startswith("dim "):
                        for name in code[4:].split(","):
                            name = name.strip().lower()
                            self.assertNotIn(name, declared, f"Duplicate Dim at {number}")
                            declared.add(name)
                    elif re.match(r"^if\b.*\bthen\s*$", lower):
                        block_stack.append("if")
                    elif lower.startswith("for "):
                        block_stack.append("for")
                    elif lower in ("end sub", "end function", "end if") or lower.startswith("next"):
                        expected = "for" if lower.startswith("next") else lower.split()[1]
                        self.assertTrue(block_stack, f"Unexpected {lower} at {number}")
                        self.assertEqual(block_stack.pop(), expected, f"Block mismatch at {number}")
                        if expected in ("sub", "function"):
                            scopes.pop()
                self.assertEqual(depth, 0, "Unbalanced parentheses")
                self.assertFalse(statement, "Dangling continuation")
                self.assertFalse(block_stack, "Unclosed blocks")


if __name__ == "__main__":
    unittest.main(verbosity=2)
