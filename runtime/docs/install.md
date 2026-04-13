# Runtime Installation Notes

The public user-facing flow now goes through `REAPER Audio Tag: Setup`, which installs the bundled runtime from the matching GitHub release.

For source checkouts and development work, keep using the repository root bootstrap:

```bash
./scripts/bootstrap.command
```

For local development, you can also work with the runtime package directly after installing the repository in editable mode.

Default bootstrap installs the packaged runtime into the managed REAPER virtual environment. For development-only editable installs, use:

```bash
./scripts/bootstrap_runtime.sh --dev
```
