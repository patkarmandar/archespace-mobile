/// Human-friendly vault recovery codes, ported from the web `recoveryCode.js`.
/// Must stay format-compatible so a code created on one client works on the
/// other: 12 lowercase letters/digits, normalized before use.
library;

import 'dart:math';

const String _alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
const int recoveryCodeLength = 12;

/// Generate a fresh recovery code using unbiased rejection sampling, matching
/// the web generator (reject bytes at or above the largest multiple of the
/// alphabet size that fits in a byte, so every symbol is equally likely).
String generateRecoveryCode() {
  final rng = Random.secure();
  final n = _alphabet.length;
  final limit = (256 ~/ n) * n; // 252 for n = 36
  final buffer = StringBuffer();
  while (buffer.length < recoveryCodeLength) {
    final b = rng.nextInt(256);
    if (b >= limit) continue;
    buffer.write(_alphabet[b % n]);
  }
  return buffer.toString();
}

/// Lowercase and strip anything outside the alphabet, so codes copied with
/// spaces or dashes still match.
String normalizeRecoveryCode(String value) {
  return value.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
}

/// Returns an error message, or null when the code is well-formed.
String? validateRecoveryCode(String value) {
  final code = normalizeRecoveryCode(value);
  if (code.length != recoveryCodeLength) {
    return 'Recovery code must be $recoveryCodeLength lowercase letters or numbers.';
  }
  return null;
}
