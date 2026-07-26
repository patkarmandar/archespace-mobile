# archespace-mobile

Mobile app for [Arche Space](https://github.com/patkarmandar/archespace) — an
open-source, private, end-to-end encrypted space. Built with Flutter for Android
and iOS. **WIP.**

It talks to the **same Supabase backend** as the web app and shares the same
zero-knowledge model: content is encrypted on-device and the server only ever
stores ciphertext. That means the mobile crypto must be byte-compatible with the
web — which is what the current spike proves.

## Status: crypto-contract spike

Before building UI, this repo validates that Dart can reproduce and consume the
exact `arc1` encryption format the web app uses (AES-256-GCM + Argon2id/PBKDF2).
This is the go/no-go gate for the whole port.

- `spec/crypto-format.md` — the language-neutral crypto contract.
- `spec/vectors.json` — conformance vectors, generated from the **web** crypto
  (`archespace/scripts/gen-crypto-vectors.mjs`) and vendored here. Do not
  hand-edit; re-copy from the web repo when the crypto changes.
- `lib/core/crypto/arche_crypto.dart` — the Dart port of the contract.
- `test/crypto_vectors_test.dart` — runs the port against every vector.

### Run the spike

Requires the Dart SDK (bundled with Flutter):

```bash
dart pub get
dart test
```

Green means the Dart crypto matches the web byte-for-byte and the port is safe
to build on. If it fails, the parameters or encoding drifted — fix before
writing any app code.

## Planned architecture (after the spike)

- **Backend**: same Supabase project via `supabase_flutter` (add mobile deep-link
  redirect URLs for auth emails). Data access behind a repository interface so a
  future first-party backend can swap in.
- **Key storage**: wrapped master key in the iOS Keychain / Android Keystore via
  `flutter_secure_storage`, gated by biometrics (`local_auth`).
- **Features**: notes, lists, tables, drawings, secrets — parity with the web
  item types.
- **Push**: "something changed" signals only (never content), sent server-side.

## License

MIT — see [LICENSE](LICENSE).
