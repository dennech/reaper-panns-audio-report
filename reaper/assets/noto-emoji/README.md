# Noto Emoji Assets

These PNG files are vendored from `googlefonts/noto-emoji`.

- Upstream repo: `https://github.com/googlefonts/noto-emoji`
- Pinned commit: `8998f5dd683424a73e2314a8c1f1e359c19e8742`
- Asset folder source: `png/128/`
- License: see the adjacent [`LICENSE`](LICENSE) file copied from upstream

The REAPER UI does not render system text emoji reliably on the current ReaImGui stack, so the report uses bundled image assets instead.

To rebuild the Lua bundles after changing these PNG files, run:

```bash
python3 scripts/generate_report_emoji_assets.py
```
