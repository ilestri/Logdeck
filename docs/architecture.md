# Architecture

## Shape

Logdeck is split into two Swift Package targets:

- `Logdeck`: the executable macOS app entry point.
- `LogdeckCore`: domain models, file loading, parsing, filtering, view model state, and SwiftUI views.

The split keeps parsing and filtering testable without launching the app.

## Core Flow

```text
File URL
  -> LogFileLoader
  -> LogParser
  -> LogSource
  -> LogWorkspaceViewModel
  -> SwiftUI views

.logdeck file
  -> LogWorkspaceStore
  -> LogWorkspaceDocument
  -> LogWorkspaceViewModel

OSLogStore.local()
  -> UnifiedLogReader
  -> LogSource
  -> LogWorkspaceViewModel

.logarchive URL
  -> OSLogStore(url:)
  -> UnifiedLogReader
  -> LogSource
  -> LogWorkspaceViewModel
```

## Important Boundaries

- `LogFileLoader` reads bounded chunks from disk and avoids UI concerns.
- `UnifiedLogReader` imports recent local unified logs and `.logarchive` packages through `OSLogStore`.
- `LogParser` converts raw text into `LogEntry` values.
- `LogCorrelationExtractor` extracts common request, trace, correlation, session, and transaction identifiers.
- `LogMetadataFilters` applies Unified Logging subsystem, process, and category filters after text and level filtering.
- `LogQueryFilter` applies query and level filtering.
- `LogWorkspaceStore` reads and writes versioned `.logdeck` JSON workspace files.
- `LogWorkspaceViewModel` owns loaded sources, display mode, current selection, query, metadata filter state, and a cached visible-entry snapshot for rendering.
- SwiftUI views render state and forward user actions.

## Near-Term Risks

- Very large logs need incremental indexing instead of full in-memory arrays.
- Tail mode needs file watching and append-only reads.
- Unified Logging access may require explicit entitlement and permission decisions.
- Keep local source-run verification fast enough for routine changes.
