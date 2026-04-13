#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import tempfile
import tomllib
import zipfile
from pathlib import Path


INSTALL_COMMAND = """#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAPER_RESOURCE_PATH="${REAPER_RESOURCE_PATH:-${HOME}/Library/Application Support/REAPER}"
TARGET_DIR="${REAPER_RESOURCE_PATH}/Scripts/reaper"

mkdir -p "${TARGET_DIR}"
rsync -a "${SCRIPT_DIR}/reaper/" "${TARGET_DIR}/"

cat <<EOF
Installed REAPER Audio Tag scripts into:
  ${TARGET_DIR}

Next steps:
1. Open REAPER.
2. Load "REAPER Audio Tag.lua" and "REAPER Audio Tag - Setup.lua" from Scripts/reaper into the Actions list.
3. Run "REAPER Audio Tag: Setup".
4. Run "REAPER Audio Tag".
EOF
"""


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_project_version(repo_root: Path) -> str:
    payload = tomllib.loads((repo_root / "pyproject.toml").read_text(encoding="utf-8"))
    return payload["project"]["version"]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--bundle-key", required=True)
    parser.add_argument("--output-dir", default="dist")
    parser.add_argument("--metadata-json")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    output_dir = Path(args.output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    package_version = read_project_version(repo_root)

    archive_name = f"REAPER-Audio-Tag-{package_version}-{args.bundle_key}.zip"
    archive_path = output_dir / archive_name

    with tempfile.TemporaryDirectory(prefix="reaper-audio-tag-installer-") as temp_dir_raw:
        temp_dir = Path(temp_dir_raw)
        stage_root = temp_dir / "REAPER Audio Tag"
        reaper_root = stage_root / "reaper"
        shutil.copytree(repo_root / "reaper", reaper_root)
        install_path = stage_root / "Install.command"
        install_path.write_text(INSTALL_COMMAND, encoding="utf-8")
        install_path.chmod(0o755)
        (stage_root / "README-install.txt").write_text(
            "Run Install.command, then load REAPER Audio Tag - Setup.lua inside REAPER and run the setup action.\n",
            encoding="utf-8",
        )

        with zipfile.ZipFile(archive_path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
            for file_path in sorted(stage_root.rglob("*")):
                archive.write(file_path, file_path.relative_to(temp_dir))

    metadata = {
        "bundle_key": args.bundle_key,
        "filename": archive_name,
        "sha256": sha256_file(archive_path),
        "size_bytes": archive_path.stat().st_size,
        "package_version": package_version,
        "release_tag": f"v{package_version}",
    }
    metadata_path = Path(args.metadata_json).resolve() if args.metadata_json else output_dir / f"{args.bundle_key}.manual-installer.json"
    metadata_path.write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"archive": str(archive_path), "metadata": str(metadata_path)}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
