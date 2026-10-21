"""Kiểm tra độc lập: nguồn tham chiếu và thư viện gốc; không xác nhận CAD."""
from pathlib import Path
import hashlib
import zipfile
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ["17_10_2026_vivaldi.aedt", "Phan_tich_chi_tiet_Vivaldi_dual_pol_17_10_2026.md",
           "Standard_Vivaldi_GUI.m", "hfss-api-master.zip"]
BASELINE_SHA256 = {'17_10_2026_vivaldi.aedt': '631820b2c07f457fd22f5cdab2aeae15694788c869629935460b2cefda1ba619', 'Phan_tich_chi_tiet_Vivaldi_dual_pol_17_10_2026.md': '49c5cbc0bc445e9bad6df008d9487f987c5db99cee7aca567fed0b205ad6e912', 'Standard_Vivaldi_GUI.m': '7da1cc728b45a7d0e9e4a5d2d1bed3d652a04ddd569d8ebdd3c4da30e0432ea2', 'hfss-api-master.zip': '6116ad5105d45d67af83282bfcae08129f3ca8521beb6e5adb52e56cd9a93bc6'}
for name in SOURCES:
    assert hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == BASELINE_SHA256[name], f"Nguồn bị sửa: {name}"
assert hashlib.sha256((ROOT / SOURCES[0]).read_bytes()).hexdigest() == (
    "631820b2c07f457fd22f5cdab2aeae15694788c869629935460b2cefda1ba619")
with zipfile.ZipFile(ROOT / "hfss-api-master.zip") as archive:
    files = [n for n in archive.namelist() if not n.endswith("/")]
    for name in files:
        local = ROOT / "third_party/hfss-api" / Path(name).relative_to("hfss-api-master")
        assert local.read_bytes() == archive.read(name), f"Vendor bị sửa: {name}"
for name in ("Vivaldi_GUI.m", "Vivaldi_Calculation.m", "Vivaldi_HFSS_Builder.m", "Vivaldi_HFSS_Simulation.m"):
    code = (ROOT / name).read_text()
    for banned in ("actxserver", "actxGetRunningServer", "restoredefaultpath", "savepath("):
        assert banned not in code, (name, banned)
if len(sys.argv) > 1:
    script = Path(sys.argv[1]).read_bytes()
    assert not script.startswith((b"\xef\xbb\xbf", b"\xff\xfe"))
    assert all(c < 128 for c in script)
    text = script.decode("ascii")
    assert not re.search(r"^Check ", text, re.M), "Check chưa có Exit Sub"
    assert text.rstrip().endswith("End Sub\nMain")
    # Loại chuỗi và comment trước khi kiểm tra dấu ngoặc lồng nhau.
    stripped = re.sub(r'"(?:[^"\r\n]|"")*"', '""', text)
    depth = 0
    for char in stripped:
        if char == "(": depth += 1
        if char == ")": depth -= 1
        assert depth >= 0, "Dư dấu ngoặc đóng VBScript"
    assert depth == 0, "Dư dấu ngoặc mở VBScript"
print(f"PASS: 4 nguồn bất biến, {len(files)} tệp vendor nguyên bản, kiến trúc MATLAB/VBScript" +
      (", cấu trúc script được kiểm tra (chưa thực thi HFSS)" if len(sys.argv) > 1 else ""))
