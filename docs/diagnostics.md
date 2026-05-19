# Diagnostics

## Strategy

Logdeck uses a local-first diagnostic strategy. The privacy summary is tracked in [PRIVACY.md](../PRIVACY.md).

- No automatic telemetry or network upload.
- In-app recoverable errors are stored in a small recent-event buffer.
- The toolbar can export a JSON diagnostic report.
- Crash reports remain macOS-owned artifacts and can be paired with the in-app report when investigating a failure locally.

Apple recommends using complete Apple crash reports when possible because third-party crash reports can omit important information. For Logdeck, a local debugging bundle is:

1. `Logdeck Diagnostics.json` exported from the app.
2. The matching Logdeck `.ips` crash report from macOS Console or DiagnosticReports.
3. Optional sample log files only when needed for the local investigation.

## Report Contents

The exported JSON report includes:

- App version and build.
- macOS version, CPU count, and memory size.
- Current view state: display mode, active filters, entry counts, and error or fault counts.
- Source summaries: name, source kind, entry count, truncation state, tail support, and load time.
- Recent app events: loading, workspace, tail, unified-log, and diagnostics errors or warnings.

The report does not include raw log lines or source file paths. Event messages redact the current user's home directory as `~`.

## Workflow

Use the toolbar diagnostics button to save:

```text
Logdeck Diagnostics.json
```

For crashes, pair the exported diagnostics file with the macOS crash report from the same timestamp. Console.app shows crash and diagnostic reports, and Apple's Xcode documentation covers how to acquire crash reports and diagnostic logs for development investigation:

- [Acquiring crash reports and diagnostic logs](https://developer.apple.com/documentation/xcode/acquiring-crash-reports-and-diagnostic-logs)
- [View reports in Console on Mac](https://support.apple.com/guide/console/view-reports-cnsl664be99a/mac)

Keep diagnostics local unless a redacted sample is intentionally exported for another debugging tool.

## Future Threshold

Add a hosted crash reporter only after there is a clear privacy design and consent flow. Until then, a local JSON report plus Apple's crash report is enough for debugging without adding data-retention, privacy, or symbol-upload operations.
