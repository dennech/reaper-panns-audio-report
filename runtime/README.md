# Runtime

This directory contains the Python runtime package used by the REAPER action.

## CLI

- `reaper-panns-runtime bootstrap`
- `reaper-panns-runtime probe`
- `reaper-panns-runtime analyze`

## Responsibilities

- runtime config for the REAPER user data directory
- backend probing with `MPS -> CPU` fallback
- PANNs `Cnn14` loading
- mono downmix + `32 kHz` preprocessing before clip-level tagging
- JSON contract handling for the Lua bridge

## Notes

- The runtime package lives under `runtime/src/reaper_panns_runtime`.
- Public users are expected to install Python, third-party dependencies, and the model file explicitly, then point `REAPER Audio Tag: Configure` at those paths.
- Development and recovery tooling can still use `bootstrap` and `.local-models/` for local checkouts.
- The fake model path exists to keep tests and contract validation lightweight.
- `scripts/bootstrap_runtime.sh` installs a regular packaged runtime by default; use `--dev` for an editable development install.
