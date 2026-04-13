# Noto Emoji Assets

These PNG files are vendored from `googlefonts/noto-emoji`.

- Upstream repo: `https://github.com/googlefonts/noto-emoji`
- Pinned commit: `8998f5dd683424a73e2314a8c1f1e359c19e8742`
- Asset folder source: `png/128/`
- This project vendors image assets only. It does not bundle the Noto Emoji font files.

## Licensing

Upstream documents a split license model in its README:

- Emoji fonts under `fonts/` are `SIL Open Font License 1.1`
- Tools and most image resources are `Apache License 2.0`

This project uses the PNG image resources from `png/128/`, so keep both adjacent license texts for clarity:

- [`LICENSE-APACHE-2.0.txt`](LICENSE-APACHE-2.0.txt): Apache 2.0 text for the bundled image resources we use
- [`LICENSE`](LICENSE): upstream OFL 1.1 text copied from the repository root for reference about the font software

See also [`../../../THIRD_PARTY_NOTICES.md`](../../../THIRD_PARTY_NOTICES.md) for the project-level attribution note.

The REAPER UI does not render system text emoji reliably on the current ReaImGui stack, so the report uses bundled image assets instead.

To rebuild the Lua bundles after changing these PNG files, run:

```bash
python3 scripts/generate_report_emoji_assets.py
```
