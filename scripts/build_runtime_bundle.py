#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
import platform
import shutil
import subprocess
import sys
import tarfile
import tempfile
import tomllib
from pathlib import Path


MODEL_FILENAME = "Cnn14_mAP=0.431.pth"
MODEL_SHA256 = "0dc499e40e9761ef5ea061ffc77697697f277f6a960894903df3ada000e34b31"
BUNDLE_SCHEMA = "reaper-audio-tag/runtime-bundle/v1"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def run(*args: str, cwd: Path | None = None, env: dict[str, str] | None = None) -> None:
    subprocess.run(list(args), check=True, cwd=cwd, env=env)


def read_project_version(repo_root: Path) -> str:
    payload = tomllib.loads((repo_root / "pyproject.toml").read_text(encoding="utf-8"))
    return payload["project"]["version"]


def detect_bundle_key() -> str:
    machine = platform.machine().lower()
    if machine in {"arm64", "aarch64"}:
        return "macos-arm64"
    if machine in {"x86_64", "amd64"}:
        return "macos-x86_64"
    raise SystemExit(f"Unsupported macOS architecture: {machine}")


def resolve_model_path(repo_root: Path, explicit_path: Path | None) -> Path:
    candidates = []
    if explicit_path is not None:
        candidates.append(explicit_path)
    candidates.extend(
        [
            repo_root / ".local-models" / MODEL_FILENAME,
            Path.home() / "Library" / "Application Support" / "REAPER" / "Data" / "reaper-panns-item-report" / "models" / MODEL_FILENAME,
        ]
    )
    for candidate in candidates:
        if candidate.exists() and sha256_file(candidate) == MODEL_SHA256:
            return candidate
    raise SystemExit(
        "Could not find a verified PANNs checkpoint. Pass --model-path or place the file in .local-models/."
    )


def resolve_python_home(python_executable: Path, explicit_home: Path | None) -> tuple[Path, Path]:
    if explicit_home is not None:
        python_home = explicit_home.resolve()
    else:
        python_home = Path(
            subprocess.check_output(
                [
                    str(python_executable),
                    "-c",
                    "import sys; print(sys.prefix)",
                ],
                text=True,
            ).strip()
        ).resolve()
    executable = python_executable.resolve()
    relative_executable = executable.relative_to(python_home)
    return python_home, relative_executable


def build_project_wheel(repo_root: Path, output_dir: Path) -> Path:
    output_dir.mkdir(parents=True, exist_ok=True)
    run(sys.executable, "-m", "build", "--wheel", "--outdir", str(output_dir), cwd=repo_root)
    wheels = sorted(output_dir.glob("reaper_panns_item_report-*.whl"))
    if not wheels:
        raise SystemExit("Wheel build did not produce a runtime wheel.")
    return wheels[-1]


def copy_python_tree(source: Path, destination: Path) -> None:
    if destination.exists():
        shutil.rmtree(destination)
    shutil.copytree(source, destination, symlinks=False)


def write_bundle_manifest(
    path: Path,
    *,
    package_version: str,
    bundle_key: str,
    python_exec_relpath: Path,
) -> None:
    payload = {
        "schema_version": BUNDLE_SCHEMA,
        "package_version": package_version,
        "bundle_key": bundle_key,
        "model_filename": MODEL_FILENAME,
        "model_sha256": MODEL_SHA256,
        "runtime_python_path": str(Path("runtime") / "python" / python_exec_relpath),
        "runtime_entrypoint_path": str(Path("runtime") / "python" / "bin" / "reaper-panns-runtime"),
    }
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--output-dir", default="dist")
    parser.add_argument("--bundle-key")
    parser.add_argument("--model-path")
    parser.add_argument("--python-executable", default=sys.executable)
    parser.add_argument("--python-home")
    parser.add_argument("--metadata-json")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    output_dir = Path(args.output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    package_version = read_project_version(repo_root)
    bundle_key = args.bundle_key or detect_bundle_key()
    model_path = resolve_model_path(repo_root, Path(args.model_path).resolve() if args.model_path else None)
    python_home, python_exec_relpath = resolve_python_home(
        Path(args.python_executable),
        Path(args.python_home).resolve() if args.python_home else None,
    )
    wheel_dir = output_dir / "wheelhouse"
    wheel_path = build_project_wheel(repo_root, wheel_dir)

    archive_name = f"reaper-audio-tag-{package_version}-{bundle_key}-runtime-bundle.tar.gz"
    archive_path = output_dir / archive_name

    with tempfile.TemporaryDirectory(prefix="reaper-audio-tag-bundle-") as temp_dir_raw:
        temp_dir = Path(temp_dir_raw)
        bundle_root = temp_dir / "bundle"
        runtime_root = bundle_root / "runtime"
        bundled_python_root = runtime_root / "python"
        models_root = bundle_root / "models"
        models_root.mkdir(parents=True, exist_ok=True)

        copy_python_tree(python_home, bundled_python_root)
        bundled_python = bundled_python_root / python_exec_relpath
        run(str(bundled_python), "-m", "pip", "install", "--upgrade", "pip", "setuptools", "wheel")
        run(str(bundled_python), "-m", "pip", "install", str(wheel_path))

        shutil.copy2(model_path, models_root / MODEL_FILENAME)
        write_bundle_manifest(
            bundle_root / "bundle-manifest.json",
            package_version=package_version,
            bundle_key=bundle_key,
            python_exec_relpath=python_exec_relpath,
        )

        smoke_env = os.environ.copy()
        smoke_env.pop("REAPER_PANNS_REPO_ROOT", None)
        run(
            str(bundled_python),
            "-c",
            "import reaper_panns_runtime, torch; print(reaper_panns_runtime.__version__, torch.__version__)",
            env=smoke_env,
        )

        with tarfile.open(archive_path, "w:gz") as archive:
            archive.add(bundle_root, arcname="bundle")

    metadata = {
        "bundle_key": bundle_key,
        "filename": archive_name,
        "sha256": sha256_file(archive_path),
        "size_bytes": archive_path.stat().st_size,
        "package_version": package_version,
        "release_tag": f"v{package_version}",
        "model_sha256": MODEL_SHA256,
        "model_filename": MODEL_FILENAME,
    }
    metadata_path = Path(args.metadata_json).resolve() if args.metadata_json else output_dir / f"{bundle_key}.runtime-bundle.json"
    metadata_path.write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")

    print(json.dumps({"archive": str(archive_path), "metadata": str(metadata_path)}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
