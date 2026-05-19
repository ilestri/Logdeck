# Roadmap

## 0.1 Local Viewer

- SwiftUI app skeleton.
- Multi-file open.
- Search and level filters.
- JSON line parsing.
- Detail inspector.
- Parser and filter tests.

## 0.2 Tail and Scale

- Follow file changes. `Implemented: polling-based append reads for the selected source.`
- Append new lines without reloading the full file.
- Virtualized rendering for large files. `Implemented: native Table rendering backed by cached visible-entry snapshots.`
- Error-neighborhood navigation. `Implemented: visible error/fault jumps plus selected-line context.`

## 0.3 Timeline

- Merge multiple sources by timestamp. `Implemented: Source/Timeline segmented display with stable timestamp ordering.`
- Request ID and trace ID pinning. `Implemented: selected-line token extraction and pinned filtering.`
- Saved workspaces. `Implemented: versioned .logdeck JSON files for source paths and view state.`

## 0.4 macOS Logs

- Read local unified logs through `OSLogStore`. `Implemented: recent local unified log import as a non-file-backed source.`
- Import `.logarchive` files. `Implemented: OSLogStore(url:) archive import with workspace path persistence.`
- Add subsystem, process, category, and level filters. `Implemented: Unified metadata filter bar plus existing level toggles.`

## Repository

- Repository links. `Implemented: docs/github.md keeps the repository and clone URL in one place.`
- Privacy posture. `Implemented: PRIVACY.md documents local-first data handling and diagnostics boundaries.`
- Local app install. `Implemented: scripts/install_app.sh builds, signs, installs, and opens a local .app bundle.`
