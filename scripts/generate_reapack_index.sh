#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if command -v reapack-index >/dev/null 2>&1; then
  REAPACK_INDEX_BIN="$(command -v reapack-index)"
elif command -v ruby >/dev/null 2>&1; then
  GEM_USER_BIN="$(ruby -e 'require "rubygems"; print File.join(Gem.user_dir, "bin", "reapack-index")')"
  if [[ -x "${GEM_USER_BIN}" ]]; then
    REAPACK_INDEX_BIN="${GEM_USER_BIN}"
  else
    REAPACK_INDEX_BIN="$(find "${HOME}/.gem/ruby" -path '*/bin/reapack-index' -print -quit 2>/dev/null || true)"
  fi
else
  REAPACK_INDEX_BIN="$(find "${HOME}/.gem/ruby" -path '*/bin/reapack-index' -print -quit 2>/dev/null || true)"
fi

if [[ ! -x "${REAPACK_INDEX_BIN}" ]]; then
  echo "reapack-index was not found. Install it with: gem install reapack-index --user-install" >&2
  exit 1
fi

cd "${REPO_ROOT}"

if [[ "${1:-}" == "--check" ]]; then
  "${REAPACK_INDEX_BIN}" --check .
else
  "${REAPACK_INDEX_BIN}" --scan . --no-commit --output index.xml .
fi
