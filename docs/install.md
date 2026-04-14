# Installation

## Recommended macOS flow

### 1. Install REAPER and ReaPack

1. Install REAPER `7.x`.
2. Open REAPER and check whether `Extensions -> ReaPack -> Browse Packages...` exists.
3. If it is missing:
   - download ReaPack from [reapack.com](https://reapack.com/)
   - in REAPER, open `Options -> Show REAPER resource path in Finder`
   - place the downloaded ReaPack file into the `UserPlugins` folder there
   - restart REAPER

### 2. Import this project's ReaPack repository

1. In REAPER, open `Extensions -> ReaPack -> Import repositories...`.
2. Add:

   `https://raw.githubusercontent.com/dennech/reaper-audio-tag/main/index.xml`

3. Open `Extensions -> ReaPack -> Browse Packages...`.
4. Search for `REAPER Audio Tag`.
5. Install the package.

### 3. Install ReaImGui

1. In ReaPack, search for `ReaImGui: ReaScript binding for Dear ImGui`.
2. Install it.
3. Restart REAPER.

### 4. Install Python 3.11

Install Python `3.11` separately.

Recommended:

- the official macOS installer from python.org

Then confirm in Terminal:

```bash
python3.11 --version
```

### 5. Create a local venv and install Python dependencies

Recommended target:

```text
~/Library/Application Support/REAPER/Data/reaper-panns-item-report/venv
```

Manual transparent path:

```bash
mkdir -p "$HOME/Library/Application Support/REAPER/Data/reaper-panns-item-report"
python3.11 -m venv "$HOME/Library/Application Support/REAPER/Data/reaper-panns-item-report/venv"
source "$HOME/Library/Application Support/REAPER/Data/reaper-panns-item-report/venv/bin/activate"
python -m pip install --upgrade pip
python -m pip install \
  "numpy>=1.26,<2.0" \
  "soundfile>=0.12,<1.0" \
  "torch==2.6.0" \
  "torchaudio==2.6.0" \
  "torchlibrosa==0.1.0"
```

Optional helper for source checkouts or manual repository downloads:

```bash
./scripts/setup_runtime_macos.sh
```

That helper is optional convenience only. It runs in Terminal, not in REAPER, and does not download the model.

### 6. Download the model manually

Required model:

- file: `Cnn14_mAP=0.431.pth`
- size: about `327 MB`
- sha256: `0dc499e40e9761ef5ea061ffc77697697f277f6a960894903df3ada000e34b31`

Recommended source:

- [Zenodo checkpoint download](https://zenodo.org/records/3987831/files/Cnn14_mAP%3D0.431.pth)

Verify the checksum:

```bash
shasum -a 256 /path/to/Cnn14_mAP=0.431.pth
```

### 7. Run Configure inside REAPER

1. Open the Actions list.
2. Run `REAPER Audio Tag: Configure`.
3. Set:
   - Python executable
   - model file
4. Click `Validate`.
5. Click `Save`.

### 8. Run the report

1. Select exactly one audio item.
2. Run `REAPER Audio Tag`.

If the configuration is missing or invalid, the main action opens `Configure`.

## Notes

- `FFmpeg` is not required for the current version.
- REAPER does not install Python for you.
- REAPER does not download the model for you.
- This project currently uses its own ReaPack repository URL directly.

## Developer setup

Source checkout workflows can still use:

1. `git clone`
2. `scripts/bootstrap.command`
3. manually loading `reaper/REAPER Audio Tag.lua`

That remains developer and recovery tooling only, not the main public install path.
