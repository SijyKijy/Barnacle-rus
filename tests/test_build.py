import hashlib
import sys
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from build import catalog, validate_payload
from version import parse_version, select_version


class ReleaseTests(unittest.TestCase):
    def test_version_selection(self):
        self.assertEqual(select_version("", "1.0.0", []), "1.0.1")
        self.assertEqual(select_version("", "1.0.0", ["v1.0.9", "v1.0.10", "other"]), "1.0.11")
        self.assertEqual(select_version("v2.1.0", "1.0.0", ["v1.5.0"]), "2.1.0")
        self.assertEqual(select_version("1.0.0", "1.0.0", []), "1.0.0")
        with self.assertRaises(ValueError):
            select_version("1.0.0", "1.0.0", ["v1.0.0"])

    def test_invalid_versions(self):
        for value in ("../1.0.0", "1.2", "01.2.3", "1.0.0;echo bad", "1.0.0\nBAD"):
            with self.assertRaises(ValueError):
                parse_version(value)

    def test_catalog(self):
        translations, count = catalog()
        self.assertEqual(count, 1564)
        self.assertEqual(len(translations), 1487)

    def test_payload(self):
        folder = ROOT / "dist"
        archives = list(folder.glob("Barnacle-RU-*.zip"))
        self.assertTrue(archives)
        for path in archives:
            with zipfile.ZipFile(path) as archive:
                self.assertIsNone(archive.testzip())
                payload = {name: archive.read(name) for name in archive.namelist()}
            validate_payload(payload)
            self.assertEqual(payload["Barnacle-RU-VERSION.txt"].decode().strip(), path.stem.removeprefix("Barnacle-RU-"))
            for name, content in payload.items():
                self.assertEqual(content, (folder / path.stem / name).read_bytes())
        checksum, filename = (folder / "SHA256SUMS.txt").read_text().strip().split("  ")
        self.assertEqual(checksum, hashlib.sha256((folder / filename).read_bytes()).hexdigest())

    def test_no_development_modes(self):
        source = (ROOT / "src/barnacle_ru/init.lua").read_text(encoding="utf-8")
        for marker in ("barnacle_ru_qa", "engine.unlock_achievement =", "engine.after(3"):
            self.assertNotIn(marker, source)


if __name__ == "__main__":
    unittest.main()
