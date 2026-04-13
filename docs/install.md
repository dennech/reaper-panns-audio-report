# Installation

## Recommended macOS flow

### 1. Install REAPER and ReaPack

1. Install REAPER `7.x`.
2. Open REAPER and check whether `Extensions -> ReaPack -> Browse Packages...` exists.
3. If that menu is missing:
   - download ReaPack from [reapack.com](https://reapack.com/)
   - in REAPER, open `Options -> Show REAPER resource path in Finder`
   - place the downloaded ReaPack file into the `UserPlugins` folder there
   - restart REAPER

### 2. Import the REAPER Audio Tag repository into ReaPack

1. In REAPER, open `Extensions -> ReaPack -> Import repositories...`.
2. Add this repository URL:

   `https://raw.githubusercontent.com/dennech/reaper-audio-tag/main/index.xml`

3. Open `Extensions -> ReaPack -> Browse Packages...`.
4. Search for `REAPER Audio Tag`.
5. Install the package.

### 3. Install ReaImGui

1. In ReaPack, search for `ReaImGui: ReaScript binding for Dear ImGui`.
2. Install it.
3. Restart REAPER.

If `ReaImGui` is still missing later, `REAPER Audio Tag: Setup` and the main action both point you back to the same ReaPack package search.

### 4. Run the Setup action

1. Open the Actions list in REAPER.
2. Search for `REAPER Audio Tag: Setup`.
3. Run it once.
4. Wait until Setup finishes.

Setup automatically:

- downloads the version-pinned bundled runtime from the matching GitHub release
- verifies the downloaded bundle checksum
- installs the bundled Python runtime and packaged dependencies into the REAPER data directory
- installs the pinned `Cnn14_mAP=0.431.pth` checkpoint
- writes `config.json` into `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/`

You do not need to install Python separately and you do not manually fetch the PANNs model in the normal user flow.

### 5. Run the report

1. Select exactly one audio item in REAPER.
2. Search for `REAPER Audio Tag` in the Actions list.
3. Run it.

## Manual fallback

If you do not want to install through ReaPack:

1. Open the [GitHub Releases page](https://github.com/dennech/reaper-audio-tag/releases/latest).
2. Download the installer ZIP for your Mac architecture.
3. Run `Install.command`.
4. Open REAPER.
5. Run `REAPER Audio Tag: Setup`.
6. Run `REAPER Audio Tag`.

This fallback still uses the same bundled runtime and the same Setup action. It only changes how the Lua scripts are copied into REAPER.

## Developer setup

Developers can still use the source checkout flow:

1. Clone the repository.
2. Run `scripts/bootstrap.command`.
3. Add `reaper/REAPER Audio Tag.lua` to the REAPER Actions list.

`bootstrap.command` remains the development and recovery path. It is no longer the recommended public install entrypoint.

## Where runtime data is stored

- Config: `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/config.json`
- Bundled runtime: `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/runtime`
- Bundled model: `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/models`
- Jobs: `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/jobs`
- Export temp WAVs: `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/tmp`
- Export logs: `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/logs`

Developer checkouts can still prefer `<repo>/.local-models` when `bootstrap.command` is run from a writable source tree.
