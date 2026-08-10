# ArcheSpace Mobile

[![Release APK](https://github.com/patkarmandar/archespace-mobile/actions/workflows/release.yml/badge.svg)](https://github.com/patkarmandar/archespace-mobile/actions/workflows/release.yml)
[![Version](https://img.shields.io/github/v/release/patkarmandar/archespace-mobile)](https://github.com/patkarmandar/archespace-mobile/releases)

The mobile app for [ArcheSpace](https://github.com/patkarmandar/archespace) — an open source, private, encrypted space to organize everything you are working on. Built with Flutter for Android and iOS.

It talks to the **same Supabase backend** as the web app and shares the same client-side `arc1` encryption format, so a vault created on one client opens on the other. It follows the same zero-knowledge architecture: your content is encrypted on-device and the backend only ever stores ciphertext, so the server, its operators, and the developers never see your data in readable form.

## Table of contents

- [Features](#features)
- [Item types](#item-types)
- [Security model](#security-model)
- [Setup](#setup)
- [Building a release](#building-a-release)
- [Release verification](#release-verification)
- [Tech stack](#tech-stack)
- [Project structure](#project-structure)
- [Roadmap](#roadmap)
- [Help and support](#help-and-support)
- [Contributing and development](#contributing-and-development)
- [License](#license)

## Features

- Multiple spaces for separating ideas, projects, plans, references, and personal systems.
- Multiple item types for different kinds of content, including PIN-protected secrets (see [Item types](#item-types)).
- Space tags and color, shown on the spaces list.
- Pinning for important spaces and items.
- Drag-and-drop reordering for spaces and page items.
- Sort spaces and page items by default order, name, or newest, remembered per view.
- Unified search across spaces, tags, and item content, with jump-to-item.
- Bulk actions for spaces and items.
- Duplicate, move, archive, restore, and delete workflows.
- Recycle bin with restore and permanent delete.
- Archive area for hiding content without deleting it.
- One-tap copy of any item's content to the clipboard as clean plain text.
- Export a whole space or a single item to PDF via the native share/print sheet.
- Backup import/export to JSON, in the same format as the web app.
- Realtime sync and pull-to-refresh across spaces and items.
- Works offline: an encrypted read cache plus a durable write queue that replays edits when you reconnect.
- Appearance settings with `System`, `Dark`, and `Light` theme modes and multiple accent colors, synced to your account.
- Private, encrypted vault to keep your content secure (see [Security model](#security-model)).
- Biometric unlock (fingerprint or face) with the wrapped key kept in the platform keystore.
- Account management: create account, change email, change login password, forgot password, and permanent account deletion.
- Vault management: change PIN with the current PIN, reset PIN with a recovery code, and generate a new recovery code.
- Single-user by default, with an optional multi-user (sign-up) mode.
- Verifiable build hash shown in Settings, linking to the exact source commit on GitHub.

## Item types

| Type | Description |
|------|-------------|
| Note | Free-form plain text. |
| Markdown | Rich text with markdown formatting and click-to-edit preview. |
| List | Simple bullet list. |
| Numbered List | Ordered list with automatic numbering that updates as rows are added, removed, or reordered. |
| Checklist | Items with checkboxes and progress tracking. |
| Cards | Title and description pairs for planning and grouping ideas. |
| Table | Rows and columns of text with a header row. Copies as tab-separated values that paste straight into a spreadsheet. |
| Secret | PIN-protected text: the title stays visible, but the content is hidden and requires re-entering your vault PIN to view or edit. |
| Drawing | Freehand vector sketch or diagram. |
| Code | A code snippet in a monospace block with automatic syntax highlighting (language auto-detected). Copies as plain text. |

## Security model

ArcheSpace uses a device-side vault model. You sign in with Supabase Auth using a login password, then unlock a separate vault PIN or passphrase to access encrypted data - the password proves account ownership, the PIN or passphrase protects the content itself.

**Encryption**

- Space and item content (names, descriptions, tags, titles, and content) is encrypted on-device with AES-256-GCM before it reaches Supabase. Only non-sensitive metadata - IDs, timestamps, positions, and flags like pinned/archived/deleted - stays in plain form.
- The vault secret is never stored as plaintext. It can be a numeric PIN or a longer passphrase. On setup, the app generates a random vault master key, which is wrapped with a key derived from your PIN or passphrase using Argon2id, a memory-hard key-derivation function. Vaults created on the web with legacy PBKDF2 still unlock here.
- The crypto format (`arc1`) is byte-compatible with the web app and validated against shared conformance vectors (see [`spec/`](spec/)), so data encrypted on either client decrypts on the other.

**Sessions and access**

- The unlocked vault key is held in memory for the running process. Only ciphertext is ever written to disk - the offline read cache and write queue store encrypted rows.
- With biometric unlock enabled, the wrapped master key is stored in the Android Keystore / iOS Keychain and released only after a successful fingerprint or face check.
- The vault can be locked manually from Settings, and is cleared on sign out.
- Supabase Row Level Security restricts each user to their own rows.

**Recovery**

- A one-time recovery code is generated during initial vault setup and shown once - it is not emailed, so it must be saved when shown.
- The recovery code can be recreated from Settings by entering the current vault PIN.
- If the PIN is forgotten, the "Reset PIN with recovery code" flow in Settings uses the recovery code to set a new vault PIN.
- Resetting with a recovery code generates a new recovery code and invalidates the previous one.

**Account deletion**

- Deleting an account permanently removes the user and, by cascade, all of their spaces, items, and encrypted vault data.
- Deletion re-verifies both the login password and the vault PIN before proceeding.

**Limits to be aware of**

- The app cannot recover encrypted content without either the current vault PIN or the current recovery code - there's no backdoor.
- If both the vault PIN and recovery code are lost, encrypted space data cannot be decrypted.
- JSON exports are saved to your device and should be stored carefully; imported backups are encrypted before upload.
- Client-side encryption is only as safe as the code your device runs. Settings shows the exact build commit (linked to GitHub) so you can verify the running code against a tagged release (see [Release verification](#release-verification)).

## Setup

### 1. Prerequisites

- The [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel; this project builds with Flutter 3.44.x / Dart 3.12+).
- Android Studio / Xcode toolchains for the platforms you target.
- A running Supabase project - the **same one** the web app uses. Follow the web [README](https://github.com/patkarmandar/archespace#setup) to create and configure it.

### 2. Clone and install

```bash
git clone https://github.com/patkarmandar/archespace-mobile
cd archespace-mobile
flutter pub get
```

### 3. Configure Supabase credentials

The app reads its config from `--dart-define` values at build time (never committed). Copy the example and fill in the same values the web app uses:

```bash
cp env.example.json env.json
```

```json
{
  "SUPABASE_URL": "https://your-project-id.supabase.co",
  "SUPABASE_ANON_KEY": "your-anon-key"
}
```

`env.json` is gitignored.

### 4. Add mobile redirect URLs in Supabase

Because this app shares the backend, add its auth redirect URLs alongside the web ones in **Supabase → Authentication → URL Configuration**. Password reset links open the web app's reset page (the Supabase Site URL); after resetting, sign in again on mobile.

### 5. Choose single-user or multi-user

Sign-up (the "Create account" option) is shown by default. To hide it for a single-user install, build with:

```bash
--dart-define=ALLOW_SIGNUP=false
```

Sign-up must also be enabled in Supabase Auth for account creation to succeed.

### 6. Run

```bash
flutter run --dart-define-from-file=env.json
```

## Building a release

`flutter run` leaves the build hash as `dev`. To produce a release APK stamped with the source commit, use the helper script (reads `env.json` and the current git commit):

```bash
./scripts/build-apk.ps1
```

Or invoke Flutter directly:

```bash
flutter build apk --release --dart-define-from-file=env.json --dart-define=BUILD_HASH=$(git rev-parse --short HEAD) --dart-define=BUILD_TIME=$(git log -1 --format=%cI)
```

Commit your changes first so the stamped hash exists on GitHub. The release APK is currently signed with the debug key (see `android/app/build.gradle.kts`); add a real keystore before distributing through an app store.

## Release verification

Pushing a `v*` tag runs the **Release APK** workflow ([`.github/workflows/release.yml`](.github/workflows/release.yml)), which builds the APK on CI, stamps it with the exact commit, and publishes it to a GitHub Release with a SHA-256 checksum. The build hash shown in Settings links to that commit, so anyone can confirm the installed binary was built from the audited, open-source code.

The workflow needs two repository secrets (the same values as `env.json`), set under **Settings → Secrets and variables → Actions**:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

Cut a release by tagging and pushing:

```bash
git tag v0.1.0
git push origin v0.1.0
```

You can also run the workflow manually from the Actions tab.

## Tech stack

| Layer | Technology |
|-------|------------|
| Framework | Flutter (Material 3), Dart |
| Backend | Supabase Auth, PostgreSQL, Row Level Security, Realtime (`supabase_flutter`) |
| Encryption | AES-256-GCM with Argon2id / PBKDF2 key derivation (`cryptography`) |
| Secure storage | `flutter_secure_storage` (Android Keystore / iOS Keychain) |
| Biometrics | `local_auth` |
| Markdown | `flutter_markdown` |
| PDF export | `pdf` + `printing` (native share/print sheet) |
| Files | `file_picker` (JSON backup), `path_provider` (offline cache) |
| Preferences | `shared_preferences` (theme + accent) |
| Links | `url_launcher` (build-commit link) |
| CI | GitHub Actions (stamped release APK) |

## Project structure

```text
archespace-mobile/
  .github/
    workflows/            # release.yml - stamped release APK
  android/
  ios/
  lib/
    main.dart             # bootstrap: Supabase init, appearance, write-queue replay
    src/
      app.dart            # root gate: login -> vault setup/unlock -> spaces
      features/
        auth/             # sign in, sign up, password policy
        vault/            # crypto vault, PIN/recovery, biometric unlock, setup/unlock
        spaces/           # spaces list, editor, cards
        items/            # item types, editors, cards, clipboard
        search/           # unified search + jump-to-item
        storage/          # archive + recycle bin
        settings/         # account, security, appearance, backup, build footer
        backup/           # JSON import/export
      shared/
        config/           # app config + build info
        crypto/           # arc1 port (AES-GCM, Argon2id/PBKDF2)
        data/             # encrypted offline read cache
        offline/          # durable write queue
        realtime/         # postgres-changes watcher
        export/           # PDF exporter
        sort/             # sorting helpers
        util/, widgets/
  scripts/
    build-apk.ps1         # local stamped release build
  spec/                   # crypto contract + conformance vectors
  test/
  pubspec.yaml
  env.example.json
```

Each feature follows a `data` / `domain` / `application` / `presentation` layering. Data access sits behind repositories so a future first-party backend can swap in.

## Roadmap

- **Push notifications**: "something changed" signals only (never content), sent server-side.
- **Forgot PIN on the lock screen**: today the recovery-code reset lives in Settings, which requires an unlocked vault; a locked-out user should be able to reset from the unlock screen.
- **Release signing**: ship a real Android keystore (and iOS signing) so releases are store-ready.
- **First-party backend**: mirrors the web roadmap - a self-contained backend the project owns, landing incrementally behind configuration. The zero-knowledge design does not change.

Other improvements are tracked as issues. If there is something you want to see, propose it there.

## Help and support

Need help with setup, self-hosting, login, password recovery, or vault PIN recovery? Reach out at **[help@archespace.cc](mailto:help@archespace.cc)**, or open an issue on the repository.

Before reaching out, it helps to include what you were trying to do and what happened, your deployment type (single- or multi-user), your device and OS version, and any relevant logs with secrets redacted.

## Contributing and development

Contributions are welcome, including bug fixes, features, and docs.

- Fork the repository, create a feature branch, and open a pull request against `main`.
- Keep PRs focused and include a short description of the change and why it is needed.
- Run `flutter analyze` and `flutter test` before submitting.
- The crypto port is safety-critical: if you touch `lib/src/shared/crypto/`, keep it byte-compatible with the web `arc1` format and re-run the conformance vectors.
- For larger or security-relevant changes, open an issue first so the approach can be discussed.

For development questions, contact **[dev@archespace.cc](mailto:dev@archespace.cc)**.

## License

See [LICENSE](LICENSE).
