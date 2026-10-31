import argparse
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--lua", default="lua5.1")
    parser.add_argument("--version", default=(ROOT / "VERSION").read_text().strip())
    args = parser.parse_args()
    subprocess.run([sys.executable, "-m", "unittest", "discover", "-s", "tests", "-p", "test_*.py"], cwd=ROOT, check=True)
    generated = ROOT / "dist" / ("Barnacle-RU-" + args.version) / "games/Barnacle/mods/barnacle_ru"
    files = sorted((ROOT / "dist" / ("Barnacle-RU-" + args.version)).rglob("*.lua"))
    if not files:
        raise ValueError("Run tools/build.py first")
    subprocess.run([args.lua, str(ROOT / "tests/check_syntax.lua"), *map(str, files)], check=True)
    for name, argument in (("runtime", ROOT / "src/barnacle_ru"), ("input", ROOT / "src/barnacle_ru/input.lua"),
                           ("metadata", ROOT / "src/barnacle_ru"), ("recent_chat", ROOT / "src/barnacle_ru"), ("catalog_templates", generated)):
        subprocess.run([args.lua, str(ROOT / f"tests/test_{name}.lua"), str(argument)], check=True)


if __name__ == "__main__":
    main()
