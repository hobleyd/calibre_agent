# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A Flutter desktop app (macOS, Linux, Windows) that exposes a Calibre e-book library over a local HTTPS REST API. It reads directly from Calibre's SQLite `metadata.db`, broadcasts itself via mDNS, and is designed to sync with a companion app called Paladin.

## Commands

```bash
# Install dependencies
flutter pub get

# Run in development (pick your platform)
flutter run -d macos
flutter run -d linux
flutter run -d windows

# Build release
flutter build macos --release --no-tree-shake-icons
flutter build linux --release
flutter build windows --release

# Lint / static analysis
flutter analyze

# Tests
flutter test
flutter test test/widget_test.dart  # single test file

# Regenerate app icons after changing assets/icon.png
dart run flutter_launcher_icons
```

## Architecture

**State management:** Flutter Riverpod with `NotifierProvider`. Two providers:
- `ServerNotifier` (`lib/providers/server_provider.dart`) — server lifecycle (stopped/starting/running/error), holds logs, book count, cert expiry
- `SettingsNotifier` (`lib/providers/settings_provider.dart`) — library path and port, persisted via `SharedPreferences`

**HTTP server** (`lib/server/calibre_server.dart`): Shelf + Shelf Router behind CORS and logging middleware, served over TLS. 8 REST endpoints under port 10444 (default). All timestamps are Unix epoch integers.

**Database** (`lib/database/calibre_db.dart`): Opens Calibre's `metadata.db` directly via `sqlite3`. Read operations use read-only connections. The update path (marking books read) drops Calibre's DB triggers, upserts into `custom_column_3` (is_read) and `custom_column_4` (last_read), removes "Future Reads" tag, and restores triggers.

**Services:**
- `CertService` — generates a 10-year self-signed RSA-2048 cert via `openssl` CLI, stored in the platform app-support directory
- `MdnsService` — broadcasts `calibre-agent._http._tcp` via Bonsoir with port and version attributes

**UI** (`lib/screens/home_screen.dart`): Single screen, left panel (start/stop, library path picker, port config, cert info), right panel (activity log).

## Key Conventions

- UUID validation strips `..`, `/`, `\` before any file access (path traversal guard in server)
- Book metadata queries use a single multi-JOIN SQL query; avoid N+1 patterns
- Log entries flow through `ServerNotifier.log()` — use this rather than `print()`
- The Calibre DB schema uses `books`, `custom_column_3`, `custom_column_4`, `books_series_link`, `series`, `books_ratings_link`, `ratings`, `comments`, `books_tags_link`, `tags`
