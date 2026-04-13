# Troubleshooting

## ReaImGui is missing

- Open `Extensions -> ReaPack -> Browse Packages...`.
- Install `ReaImGui: ReaScript binding for Dear ImGui`.
- Restart REAPER.
- Run `REAPER Audio Tag: Setup` again.

## `REAPER Audio Tag: Setup` is missing from the Actions list

- If you installed through ReaPack, make sure the `REAPER Audio Tag` package is installed.
- If you used the manual installer ZIP, run `Install.command` again.
- Refresh or reopen the Actions list.
- If needed, load `Scripts/reaper/REAPER Audio Tag - Setup.lua` manually.

## Setup fails to download the bundled runtime

- Check your internet connection.
- Open the [GitHub Releases page](https://github.com/dennech/reaper-audio-tag/releases/latest) and confirm the release assets are available.
- Run `REAPER Audio Tag: Setup` again.
- If the release asset was partially downloaded, delete `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/setup` and rerun Setup.

## Setup reports a checksum mismatch

- Delete `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/setup`.
- Run `REAPER Audio Tag: Setup` again.
- If the mismatch persists, check whether a proxy, mirror, or antivirus tool is rewriting downloaded archives.

## The report says Setup must be run first

- Run `REAPER Audio Tag: Setup`.
- Confirm that `config.json` exists in `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/`.
- Confirm that the bundled runtime exists under `~/Library/Application Support/REAPER/Data/reaper-panns-item-report/runtime`.

## The runtime falls back to CPU

- On Apple Silicon, this is expected when `MPS` is unavailable or unstable.
- The runtime intentionally prefers a safe fallback over a crash.

## The selected item is rejected

- Make sure exactly one item is selected.
- Make sure the active take is audio, not MIDI.
- If a report window is already open, keep it open, select the next item, and click `Another`.

## REAPER becomes sluggish when the report opens

- Make sure you are on the latest version of the script and rerun the action.
- The report now prepares export audio incrementally before runtime inference starts.
- If responsiveness still drops, note whether the slowdown happens during `Preparing audio...`, during `Listening...`, or only after the final report appears.

## The compact view does not show the colorful icons

- The current build uses bundled Noto Emoji PNG assets instead of system emoji.
- If the compact chips show text without icons, the image decode or render path is unavailable in that REAPER session.
- Analysis quality is unaffected; this is only a presentation fallback.

## I want export diagnostics without running the model

- Run `reaper/REAPER Audio Tag - Debug Export.lua`.
- It exports the selected take range, writes a diagnostics log, and stops before the Python runtime step.

## I am a developer and still want the old source-checkout bootstrap flow

- Use `scripts/bootstrap.command`.
- `bootstrap.command` is now a development and recovery path only.
- Public installs should use ReaPack or the manual installer ZIP plus `REAPER Audio Tag: Setup`.
