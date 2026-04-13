# Runtime

This directory contains the Python runtime package used by the REAPER action.

## CLI

- `reaper-panns-runtime bootstrap`
- `reaper-panns-runtime probe`
- `reaper-panns-runtime analyze`

## Responsibilities

- model download + checksum verification
- runtime config for the REAPER user data directory
- backend probing with `MPS -> CPU` fallback
- PANNs `Cnn14` loading
- mono downmix + `32 kHz` preprocessing before clip-level tagging
- JSON contract handling for the Lua bridge

## Notes

- The runtime package lives under `runtime/src/reaper_panns_runtime`.
- In a normal writable checkout, bootstrap prefers a repo-local cache under `.local-models/` for the large checkpoint and keeps it out of Git.
- If the repo-local cache is unavailable, bootstrap falls back to the REAPER data directory model cache.
- The fake model path exists to keep tests and contract validation lightweight.
- `scripts/bootstrap_runtime.sh` installs a regular packaged runtime by default; use `--dev` for an editable development install.
