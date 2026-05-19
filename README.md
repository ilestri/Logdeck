# Logdeck

Native macOS log viewer for local log files, Unified Logging, and `.logarchive`
files.

## Install

```sh
scripts/install_app.sh
```

This builds a local `.app`, installs it into `/Applications` when writable or
`~/Applications` otherwise, and opens it. Re-run the script after source changes
when the installed app should be refreshed.

## Develop

```sh
swift run Logdeck
swift build
swift test
```

## Notes

- Local-first app; no telemetry, analytics, or network upload.
- GitHub Issues, Wiki, Projects, and Actions are disabled.
- MIT licensed.
