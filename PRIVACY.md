# Privacy

Logdeck is designed as a local-first macOS log viewer. This document records the current data handling behavior of the app.

## App Data Handling

Logdeck reads data only from sources opened or requested locally:

- Local log files such as `.log`, `.txt`, `.json`, and `.jsonl`.
- Selected `.logarchive` packages.
- Recent local macOS Unified Logging entries requested from the app.
- Selected or saved `.logdeck` workspace files.

The current app does not:

- Upload logs automatically.
- Send telemetry or analytics.
- Use a hosted crash reporter.
- Make network requests from the app.
- Include raw log lines or source file paths in exported diagnostics.

## Diagnostics

The app can export `Logdeck Diagnostics.json`. The diagnostics report is intended for local debugging and includes app, system, source-summary, filter, count, and recent-event information.

The diagnostics report does not include raw log lines or source file paths. Event messages redact the current user's home directory as `~`.

Review every exported file before moving it outside the local machine. Do not export private logs, secrets, tokens, customer data, full crash reports, hostnames, or local absolute paths.

## Crash Reports

Logdeck does not collect crash reports automatically. Crash reports remain macOS-owned artifacts unless a matching `.ips` report is manually copied for local debugging.

## Future Changes

Any future telemetry, hosted crash reporting, or network upload feature should require:

- A clear user-facing privacy update.
- An explicit consent flow when personal or diagnostic data leaves the device.
- Documentation of what is collected, where it is sent, and how it is retained.
