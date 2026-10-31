import argparse
import hashlib
import json
import re
import zipfile
from pathlib import Path
from version import parse_version

ROOT = Path(__file__).resolve().parents[1]
FORMATS = re.compile(r"%(?:%|[-+ #0]*\d*\.?\d*[cdiouxXeEfgGqs])")
FONT_HASHES = {
    "Arimo-Regular.ttf": "41b22bc8f0b51f932825d37bc55b5eb6ba67dfe599a626e4aff2b43b624f9f8c",
    "Arimo-Bold.ttf": "d7a8b187cf8444d4cfee102e8eae9e3043682fd5106d5d33ed677fe268a0e2ba",
    "Arimo-Italic.ttf": "ffdf690e4357a392e4edcc3df0b3adb0302920f75e54f2e6eec355afbe7edcba",
    "Arimo-BoldItalic.ttf": "77c967d49d4ef4a63c39fbcd1e27892102e503e35a20983cb058430c4f268b34",
    "OFL.txt": "c46fda6859efb80c0a3c1faa868908a3d2fcb26eb7fd9602d73bebeec21bca3a",
}


def digest(path):
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def lua_string(value):
    escapes = {"\\": "\\\\", '"': '\\"', "\n": "\\n", "\r": "\\r", "\t": "\\t"}
    parts = []
    for char in value:
        if char in escapes:
            parts.append(escapes[char])
        elif ord(char) < 32 or (ord(char) > 127 and not char.isalnum() and not char.isspace()):
            parts.append("".join(f"\\{byte:03d}" for byte in char.encode("utf-8")))
        else:
            parts.append(char)
    return '"' + "".join(parts) + '"'


def catalog():
    translations, count = {}, 0
    for path in sorted((ROOT / "catalogs").glob("*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        rows = list(data.get("extra", []))
        for source_path, entries in data.get("files", {}).items():
            relative = Path(source_path)
            if relative.is_absolute() or ".." in relative.parts or "\\" in source_path or ":" in source_path:
                raise ValueError("Invalid catalog source path")
            rows.extend(entries)
        for source, target, *_ in rows:
            if not isinstance(source, str) or not source or not isinstance(target, str) or not target:
                raise ValueError("Empty translation in " + path.name)
            if FORMATS.findall(source) != FORMATS.findall(target):
                raise ValueError("Format mismatch in " + path.name)
            if source in translations and translations[source] != target:
                raise ValueError("Conflicting translation in " + path.name)
            translations[source] = target
            count += 1
    translations.pop("Lia: %s", None)
    return translations, count


def validate_payload(payload):
    for relative, content in payload.items():
        path = Path(relative)
        if path.is_absolute() or ".." in path.parts or relative.startswith(("bin/", "worlds/")):
            raise ValueError("Invalid payload path")
        if path.suffix.lower() in (".exe", ".dll", ".ahk", ".ps1", ".cmd", ".sqlite", ".log"):
            raise ValueError("Unexpected payload file")
        if path.suffix == ".lua" and any(marker in content for marker in (b"barnacle_ru_qa", b"qa_fixture", b"engine.unlock_achievement =")):
            raise ValueError("Development code in payload")
    config = payload["minetest.conf"].decode("utf-8")
    if re.search(r"(?:[A-Za-z]:[\\/]|barnacle_ru_qa|barnacle_qa_screen|font_path[ \t]*=)", config):
        raise ValueError("Local configuration in payload")
    assert re.search(r"^language = ru$", config, re.M)


def build(version, output=None):
    version = ".".join(map(str, parse_version(version)))
    output = Path(output) if output else ROOT / "dist"
    payload = {}
    for directory, prefix in ((ROOT / "integration", ""), (ROOT / "src/barnacle_ru", "games/Barnacle/mods/barnacle_ru/")):
        for path in sorted(directory.rglob("*")):
            if path.is_file():
                if path.is_symlink():
                    raise ValueError("Symlinks are not supported")
                payload[prefix + path.relative_to(directory).as_posix()] = path.read_text(encoding="utf-8-sig").encode("utf-8")
    translations, entries = catalog()
    modpath = "games/Barnacle/mods/barnacle_ru/"
    payload[modpath + "dictionary.lua"] = ("return {\n" + "".join(f"  [{lua_string(key)}] = {lua_string(value)},\n" for key, value in sorted(translations.items())) + "}\n").encode("utf-8")
    metadata = json.loads((ROOT / "data/world_metadata.json").read_text(encoding="utf-8"))
    payload[modpath + "metadata_sources.lua"] = ("return {\n" + "".join("  [" + lua_string(pos) + "] = {" +
        ", ".join("[" + lua_string(key) + "] = " + lua_string(value) for key, value in sorted(fields.items())) + "},\n"
        for pos, fields in sorted(metadata["positions"].items())) + "}\n").encode("utf-8")
    payload[modpath + "nodenames.lua"] = ("return {" + ",".join(map(lua_string, metadata["nodenames"])) + "}\n").encode("utf-8")
    for name, expected in FONT_HASHES.items():
        if digest(ROOT / "fonts" / name) != expected:
            raise ValueError("Font checksum mismatch: " + name)
    for style in ("Regular", "Bold", "Italic", "BoldItalic"):
        payload[f"fonts/Cousine-{style}.ttf"] = (ROOT / f"fonts/Arimo-{style}.ttf").read_bytes()
    payload["fonts/DroidSansFallbackFull.ttf"] = (ROOT / "fonts/Arimo-Regular.ttf").read_bytes()
    payload["fonts/Barnacle-RU-Arimo-OFL.txt"] = (ROOT / "fonts/OFL.txt").read_bytes()
    for source, target in (("data/minetest.conf", "minetest.conf"), ("INSTALL.txt", "README-RU.txt"), ("LICENSE", "Barnacle-RU-LICENSE.txt"), ("NOTICE", "Barnacle-RU-NOTICE.txt")):
        payload[target] = (ROOT / source).read_text(encoding="utf-8-sig").encode("utf-8")
    payload["Barnacle-RU-VERSION.txt"] = (version + "\n").encode()
    validate_payload(payload)
    folder = output / ("Barnacle-RU-" + version)
    existing = {path.relative_to(folder).as_posix() for path in folder.rglob("*") if path.is_file()}
    if existing - payload.keys():
        raise ValueError("Unexpected files in build folder")
    for relative, content in payload.items():
        target = folder / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(content)
    archive_path = output / f"Barnacle-RU-{version}.zip"
    with zipfile.ZipFile(archive_path, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for relative, content in sorted(payload.items()):
            item = zipfile.ZipInfo(relative, date_time=(2026, 1, 1, 0, 0, 0))
            item.compress_type, item.create_system, item.external_attr = zipfile.ZIP_DEFLATED, 3, 0o100644 << 16
            archive.writestr(item, content)
    with zipfile.ZipFile(archive_path) as archive:
        assert archive.testzip() is None
        assert {name: archive.read(name) for name in archive.namelist()} == payload
    hashes = {relative: hashlib.sha256(content).hexdigest() for relative, content in sorted(payload.items())}
    (output / "files-sha256.json").write_text(json.dumps({"version": version, "steam_build": "23511000", "files": hashes}, indent=2) + "\n", encoding="utf-8")
    (output / "SHA256SUMS.txt").write_text(f"{digest(archive_path)}  {archive_path.name}\n", encoding="utf-8")
    (output / "RELEASE.md").write_text((ROOT / "docs/release.txt").read_text(encoding="utf-8").replace("<версия>", version), encoding="utf-8")
    print(f"{version}: {entries} catalog entries, {len(translations)} translations, {len(payload)} files")
    return archive_path


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", default=(ROOT / "VERSION").read_text().strip())
    build(parser.parse_args().version)
