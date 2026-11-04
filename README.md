# SQLGarden

**Developed by Victor · MIT License · macOS 14+ · Apple Silicon and Intel**

A native SwiftUI/AppKit client for Microsoft SQL Server Express, featuring a
T-SQL editor, object explorer, `GO` batch support, a persistent SQL session,
multiple result sets, messages, CSV export, and optional credential storage in
macOS Keychain. No embedded Python runtime.

## 0.5.0 preview — Native workspace redesign

- Integrated the three-petal mascot, native application icon, and adaptive wordmark.
- Clearer connection identity, selected query tabs, and selection/document execution scope.
- Results can be hidden from the toolbar or View menu (Shift-Command-R); running SQL reveals them.
- Result selection belongs to each document and remains valid after results change.
- Visible multiple-result selectors with row counts; explorer expand/collapse controls.
- Native resizable panes, semantic colors, and more informative disconnected/running states.

See the [design research and plan](docs/design/0.5.0-workspace.md) and
[validation notes](docs/VALIDATION_0.5.0.md). This is a preview: real SQL Server
regressions have not been rerun for this build. Earlier release tags remain unchanged.

## What's new in 0.4.0

- Quote and accent input preserves keyboard composition.
- Object explorer with database selection, schemas, counts, and object actions.
- Asynchronous file panels attached to the application window.
- Transport failures invalidate the connection; interruptions warn about pending transactions.
- Result processing continues after DML with no affected rows, including `TRY/CATCH`.
- The password-storage preference persists between launches and is disabled by default.

## Fixes from 0.3.1

- Original SQL is preserved, including CRLF/CR line endings and Unicode marks next to quotes.
- NUL input is rejected before any batch runs; NUL characters in results are preserved.
- ODBC fields reject NUL; driver warnings do not append bytes to binary values.
- Asynchronous Keychain access, waiting state, manual password entry, and protection against delayed responses.
- File saving protects unreadable external files and detects differences in Unicode bytes.
- Stale object-explorer responses cannot repopulate a closed connection.

## Features introduced in 0.3.0

- Automatic recovery of local tabs and drafts, with atomic writes and a backup.
- Searchable SQL history with execution context and duration; history can be cleared or disabled.
- Line numbers, find and replace, go to line, comments, and indentation.
- Cell and range selection, copying with headers, local search, and long-value inspection.
- Explicit session and transaction inspection, with no automatic `COMMIT` or `ROLLBACK`.
- Feedback to sqlgarden@publicvictor.com, with editable review, optional technical
  diagnostics, and composition in the macOS email client; copying and saving are also available.

## Installation

See the **[installation guide](INSTALACAO.md)** (currently in Portuguese).
The DMG installs the application. Microsoft ODBC Driver, unixODBC, and OpenSSL 3
are installed separately through the provided dependency script. Connect to your
university's server or an existing container, or use the optional installer to
create a local SQL Server Express instance. No credentials are bundled with the app.

The universal build contains both `arm64` and `x86_64` binaries. Physical execution
was validated on the Apple Silicon Mac documented in
[macOS validation](docs/VALIDACAO_MAC.md). An Intel build is not evidence of
physical testing on an Intel Mac. Current builds are ad hoc signed and are not notarized.

## Development

Requirements: macOS 14+, Swift 5.9+, and Xcode or Command Line Tools.
The app has no external Swift package dependencies. Visual DMG packaging uses
Python 3 and `dmgbuild` at development time only; application users do not need
these tools. Asset catalog compilation uses Xcode's `actool`, so full visual
packaging requires an Xcode installation that provides it.

```bash
bash scripts/test.sh
bash scripts/test-ui.sh # macOS; optional integration uses the documented environment variables
bash scripts/build-app.sh release universal
open dist/SQLGarden.app
python3 -m venv .dmg-venv
.dmg-venv/bin/pip install -r scripts/requirements-dmg.txt
SQLGARDEN_DMG_PYTHON="$PWD/.dmg-venv/bin/python" bash scripts/build-dmg.sh
```

Use `build-app.sh release native` to build for the current architecture only.
`test.sh` uses Python 3 **only for the C bridge test helper**. Python is not
required to use or install the app, execute SQL, or compile the application.
Run the StudioCore tests independently with `swift test --filter StudioCoreTests`.

`test-integration.sh` is opt-in. It requires `SQLGARDEN_INTEGRATION_PASSWORD` in
the environment and creates a new database named `SQLGarden_Validacao_…`.
Never place passwords in command arguments or shell history.
`SQLGARDEN_TEST_DATABASE` selects a name with that prefix. The test aborts if
the database already exists and preserves its objects when it finishes.
`bash scripts/test-regressions.sh` uses the same connection variables, works
only with temporary tables, and checks limits and data-integrity regressions.
Never run these suites against a personal or production server.
The `--disconnect-check` scenario requires the explicit name of a validation
database created by the main test and terminates only the session started by that test.

## Capabilities and limitations

- Tabs, UTF-8 files, and execution of the selection or entire document.
- `GO` / `GO n` without splitting strings, identifiers, or comments.
- One SQL session shared across tabs for `USE`, transactions, and temporary tables.
- A separate metadata connection for databases, tables, views, procedures, triggers, and functions.
- Multiple result sets, `PRINT`, partial errors, cancellation, and timeouts.
- Results grid with copying and CSV export. Explicit display limits; no injected `TOP` clause.
- Controls to list, start, and stop existing containers without deleting volumes.
- Original visual assets, light/dark logos, and an appearance-aware Dock icon.

SQLGarden does not replicate every SSMS feature. It has no designers, inline
editing, diagrams, graphical execution plans, guided restore, SQLCMD, Windows
authentication, or Python integration. Syntax highlighting is simplified.
`GO /* comment */` is unsupported; put `GO` on its own line or use a `--` comment.
Drafts are recovered locally; also save SQL files to keep your own copies.
Cancellation does not automatically execute `ROLLBACK`.
Results are limited to approximately 32 MiB, 64 result sets, and 512 columns.
Large cells are capped, and binary values are displayed in hexadecimal.

## Project structure

- `Sources/SQLGarden`: macOS interface and services.
- `Sources/StudioCore`: models, escaping, CSV, and batch parser.
- `Sources/SQLBridge`: C bridge that loads unixODBC at runtime.
- `Sources/Launcher`: architecture-specific native bootstrap for OpenSSL 3.
- `Resources`: `Info.plist`, icons, and logo asset catalog.
- `Design`: original visual kit, without redesign or added effects.
- `scripts`: tests, dependency installation, optional Express setup, and reproducible packaging.
- `Tests`, `examples`, `docs`: validation, sample SQL, and architecture documentation.

## Version history

Source snapshots are available as [Git tags](https://github.com/victrbiel/SQLGarden/tags):
`v0.1.0`, `v0.2.0`, `v0.3.0`, `v0.3.1`, and `v0.4.0`.
See the [changelog](CHANGELOG.md) and [repository history](docs/REPOSITORY_HISTORY.md).
The Git history was reconstructed from preserved source snapshots; it is not
the original development commit history. Historical documents are currently in Portuguese.

## Contributing

Read the [contribution guidelines](CONTRIBUTING.md). Preserve session behavior,
Unicode and NULL handling, user data, and credentials. Report which platform,
architecture, and tests you actually validated.

## License

Copyright © 2026 Victor. SQLGarden and the artwork supplied with this project
are published under the [MIT License](LICENSE). External libraries and products
retain their own licenses; see [third-party notices](THIRD_PARTY_NOTICES.md).
This project does not redistribute Docker, SQL Server, Microsoft ODBC Driver,
or Homebrew libraries.
