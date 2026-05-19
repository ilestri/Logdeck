# Development

## Local Gate

Run the local verification checks before keeping changes:

```sh
swift build
swift test
```

The local gate is intentionally limited to source buildability and tests.

## Local App Install

To use Logdeck without running it from Xcode or SwiftPM each time:

```sh
scripts/install_app.sh
```

The script builds a release executable, wraps it in a local `.app` bundle,
ad-hoc signs it, installs it into `/Applications` when writable or
`~/Applications` otherwise, and opens the installed app.

## GitHub

Use [docs/github.md](github.md) for repository links.
