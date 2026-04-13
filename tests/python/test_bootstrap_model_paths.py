from __future__ import annotations

import os
import tempfile
from pathlib import Path
from unittest.mock import patch

from reaper_panns_runtime.bootstrap import resolve_model_path
from reaper_panns_runtime.downloader import CNN14_MODEL
from reaper_panns_runtime.paths import RuntimePaths


def _mk_paths(root: Path, repo_root: Path) -> RuntimePaths:
    return RuntimePaths(
        resource_dir=root / "REAPER",
        data_dir=root / "REAPER" / "Data" / "reaper-panns-item-report",
        runtime_dir=root / "REAPER" / "Data" / "reaper-panns-item-report" / "runtime",
        jobs_dir=root / "REAPER" / "Data" / "reaper-panns-item-report" / "jobs",
        logs_dir=root / "REAPER" / "Data" / "reaper-panns-item-report" / "logs",
        tmp_dir=root / "REAPER" / "Data" / "reaper-panns-item-report" / "tmp",
        models_dir=root / "REAPER" / "Data" / "reaper-panns-item-report" / "models",
        config_path=root / "REAPER" / "Data" / "reaper-panns-item-report" / "config.json",
        last_probe_path=root / "REAPER" / "Data" / "reaper-panns-item-report" / "last_probe.json",
        venv_dir=root / "REAPER" / "Data" / "reaper-panns-item-report" / "runtime" / "venv",
        repo_root=repo_root,
    )


def _normalized(path: Path) -> Path:
    return path.resolve(strict=False)


def test_resolve_model_path_prefers_project_local_dir() -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        repo_root = root / "repo"
        repo_root.mkdir(parents=True)
        paths = _mk_paths(root, repo_root)
        expected = _normalized(repo_root / ".local-models" / CNN14_MODEL.filename)

        def fake_download(target_dir, spec, force=False):  # noqa: ANN001 - test shim
            destination = Path(target_dir) / spec.filename
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(b"fake-model")
            return destination

        with patch.dict(os.environ, {"REAPER_PANNS_REPO_ROOT": str(repo_root)}, clear=False):
            with patch("reaper_panns_runtime.bootstrap.download_model", side_effect=fake_download):
                resolved = resolve_model_path(paths, force_download=False)

        assert _normalized(resolved) == expected


def test_resolve_model_path_falls_back_to_reaper_models_when_repo_local_unavailable() -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        repo_root = root / "missing-repo"
        paths = _mk_paths(root, repo_root)
        expected = _normalized(paths.models_dir / CNN14_MODEL.filename)

        def fake_download(target_dir, spec, force=False):  # noqa: ANN001 - test shim
            destination = Path(target_dir) / spec.filename
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(b"fake-model")
            return destination

        with patch.dict(os.environ, {"REAPER_PANNS_REPO_ROOT": str(repo_root)}, clear=False):
            with patch("reaper_panns_runtime.bootstrap.download_model", side_effect=fake_download):
                resolved = resolve_model_path(paths, force_download=False)

        assert _normalized(resolved) == expected


def test_resolve_model_path_reuses_valid_project_local_checkpoint() -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        repo_root = root / "repo"
        repo_root.mkdir(parents=True)
        paths = _mk_paths(root, repo_root)
        project_model = _normalized(repo_root / ".local-models" / CNN14_MODEL.filename)
        project_model.parent.mkdir(parents=True, exist_ok=True)
        project_model.write_bytes(b"valid-project-model")

        def fake_verify_model(path, spec):  # noqa: ANN001 - test shim
            return _normalized(Path(path)) == project_model

        with patch.dict(os.environ, {"REAPER_PANNS_REPO_ROOT": str(repo_root)}, clear=False):
            with patch("reaper_panns_runtime.bootstrap.verify_model", side_effect=fake_verify_model):
                with patch("reaper_panns_runtime.bootstrap.download_model", side_effect=AssertionError("download should not be used")):
                    resolved = resolve_model_path(paths, force_download=False)

        assert _normalized(resolved) == project_model


def test_resolve_model_path_copies_valid_legacy_checkpoint_into_project_local_dir() -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        repo_root = root / "repo"
        repo_root.mkdir(parents=True)
        paths = _mk_paths(root, repo_root)
        legacy_model = _normalized(paths.models_dir / CNN14_MODEL.filename)
        legacy_model.parent.mkdir(parents=True, exist_ok=True)
        legacy_model.write_bytes(b"legacy-valid-model")
        expected = _normalized(repo_root / ".local-models" / CNN14_MODEL.filename)

        def fake_verify_model(path, spec):  # noqa: ANN001 - test shim
            return _normalized(Path(path)) == legacy_model

        def fake_copy_verified_model(source_path, destination_path, spec, force=False):  # noqa: ANN001 - test shim
            destination = Path(destination_path)
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(Path(source_path).read_bytes())
            return destination

        with patch.dict(os.environ, {"REAPER_PANNS_REPO_ROOT": str(repo_root)}, clear=False):
            with patch("reaper_panns_runtime.bootstrap.verify_model", side_effect=fake_verify_model):
                with patch("reaper_panns_runtime.bootstrap.copy_verified_model", side_effect=fake_copy_verified_model):
                    with patch("reaper_panns_runtime.bootstrap.download_model", side_effect=AssertionError("download should not be used")):
                        resolved = resolve_model_path(paths, force_download=False)

        assert _normalized(resolved) == expected
        assert expected.read_bytes() == b"legacy-valid-model"
