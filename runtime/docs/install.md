# Runtime Installation Notes

The public REAPER flow is now transparent and manual:

- users install the Lua package with ReaPack
- users install Python `3.11` themselves
- users install the pinned Python dependencies themselves
- users download the `Cnn14_mAP=0.431.pth` checkpoint themselves
- `REAPER Audio Tag: Configure` validates those paths inside REAPER

This runtime directory therefore stays mostly developer-facing.

For source checkouts and recovery work, use:

```bash
./scripts/bootstrap.command
```

For local development with editable installs:

```bash
./scripts/bootstrap_runtime.sh --dev
```
