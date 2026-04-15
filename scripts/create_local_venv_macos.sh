#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${1:-$HOME/Library/Application Support/REAPER/Data/reaper-panns-item-report/venv}"
PYTHON_BIN="${PYTHON_BIN:-python3.11}"

mkdir -p "$(dirname "$TARGET_DIR")"

"$PYTHON_BIN" -m venv "$TARGET_DIR"
source "$TARGET_DIR/bin/activate"
python -m pip install --upgrade pip
python -m pip install \
  "numpy>=1.26,<2.0" \
  "soundfile>=0.12,<1.0" \
  "torch==2.6.0" \
  "torchaudio==2.6.0" \
  "torchlibrosa==0.1.0"

printf '\nUse this Python environment folder in REAPER Audio Tag: Configure:\n%s\n' "$TARGET_DIR"
printf '\nExpert executable path, if needed:\n%s\n' "$TARGET_DIR/bin/python"
printf '\nModel download is still manual:\n'
printf '  %s\n' "Cnn14_mAP=0.431.pth"
printf '  sha256 %s\n' "0dc499e40e9761ef5ea061ffc77697697f277f6a960894903df3ada000e34b31"
