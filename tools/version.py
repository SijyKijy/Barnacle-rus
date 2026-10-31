import os
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATTERN = re.compile(r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)")


def parse_version(value):
    value = value.strip().removeprefix("v")
    if not PATTERN.fullmatch(value):
        raise ValueError("Version must have the form X.Y.Z")
    return tuple(map(int, value.split(".")))


def select_version(requested, current, tags):
    versions = set()
    for tag in tags:
        if tag.startswith("v") and PATTERN.fullmatch(tag[1:]):
            versions.add(parse_version(tag))
    if requested.strip():
        selected = parse_version(requested)
    else:
        major, minor, patch = max(versions | {parse_version(current)})
        selected = (major, minor, patch + 1)
    if selected in versions:
        raise ValueError("This version tag already exists")
    return ".".join(map(str, selected))


def main():
    tags = subprocess.run(["git", "tag", "--list"], cwd=ROOT, check=True, capture_output=True, text=True).stdout.splitlines()
    selected = select_version(os.environ.get("REQUESTED_VERSION", ""), (ROOT / "VERSION").read_text(), tags)
    output = f"version={selected}\ntag=v{selected}\n"
    if os.environ.get("GITHUB_OUTPUT"):
        with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as destination:
            destination.write(output)
    print(output, end="")


if __name__ == "__main__":
    main()
