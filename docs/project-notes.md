# Personal Project Notes

## Goal

Logdeck exists to make large local logs easier to inspect on macOS without forcing a terminal-only workflow.

## Primary User

- The owner of this repository, debugging backend, desktop, mobile, and infrastructure logs locally.

## Current Scope

- Local file viewing.
- Fast search and level filtering.
- Tail mode for the selected file.
- Timestamp-sorted timeline across open files.
- Request ID and trace ID pinning.
- Saved `.logdeck` workspaces for reopening local log sets.
- Recent local macOS Unified Logging import.
- `.logarchive` package import.
- Unified log subsystem, process, category, and level filtering.
- Simple JSON log handling.
- Multi-file workspace.
- Selected-line inspector with neighboring log context.
- Source-run GitHub repository with clone links and local verification.

## Deferred

- Advanced faceting and saved filter presets.
- Real-time tail streaming.
- AI-assisted clustering and summaries.

## Success Criteria

- I can open a log file and find errors within seconds.
- Parser and filter behavior is covered by unit tests.
- The app remains native, lightweight, and easy to run from source.
