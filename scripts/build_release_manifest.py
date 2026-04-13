#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import tomllib
from pathlib import Path


RELEASE_MANIFEST_SCHEMA = "reaper-audio-tag/release-manifest/v1"


def read_project_version(repo_root: Path) -> str:
    payload = tomllib.loads((repo_root / "pyproject.toml").read_text(encoding="utf-8"))
    return payload["project"]["version"]


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--output")
    parser.add_argument("--runtime-metadata", nargs="+", required=True)
    parser.add_argument("--installer-metadata", nargs="*", default=[])
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    package_version = read_project_version(repo_root)
    release_tag = f"v{package_version}"
    manifest_name = f"reaper-audio-tag-{package_version}-release-manifest.json"
    output_path = Path(args.output).resolve() if args.output else (repo_root / "dist" / manifest_name)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    bundles = {}
    installers = {}
    for metadata_path in args.runtime_metadata:
        payload = load_json(Path(metadata_path).resolve())
        bundles[payload["bundle_key"]] = payload

    for metadata_path in args.installer_metadata:
        payload = load_json(Path(metadata_path).resolve())
        installers[payload["bundle_key"]] = payload

    manifest = {
      "schema_version": RELEASE_MANIFEST_SCHEMA,
      "package_version": package_version,
      "release_tag": release_tag,
      "bundles": bundles,
      "installers": installers,
    }
    output_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(str(output_path))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
