#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
REPO_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd)"
DEFAULT_VENV="$HOME/Library/Application Support/REAPER/Data/reaper-panns-item-report/runtime/venv/bin/python"

if [ -n "${PYTHON_BIN:-}" ]; then
  PYTHON="$PYTHON_BIN"
elif [ -x "$DEFAULT_VENV" ]; then
  PYTHON="$DEFAULT_VENV"
elif command -v python3.11 >/dev/null 2>&1; then
  PYTHON="$(command -v python3.11)"
elif [ -x "/opt/homebrew/bin/python3.11" ]; then
  PYTHON="/opt/homebrew/bin/python3.11"
elif [ -x "/usr/local/bin/python3.11" ]; then
  PYTHON="/usr/local/bin/python3.11"
else
  echo "Python 3.11 was not found. Set PYTHON_BIN or create the REAPER runtime venv first." >&2
  exit 1
fi

"$PYTHON" "$REPO_ROOT/tests/scripts/run_python_tests.py" --scope integration
