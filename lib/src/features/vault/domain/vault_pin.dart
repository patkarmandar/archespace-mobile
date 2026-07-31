/// Vault secret validation, ported from the web `vaultPin.js`.
///
/// The vault secret can be a numeric PIN or an alphanumeric passphrase. Only
/// length is enforced (the minimum stays low for backwards compatibility);
/// weak choices are surfaced via a warning, not blocked, so existing short
/// PINs keep working.
library;

const int vaultPinMinLength = 4;
const int vaultPinMaxLength = 64;

final RegExp _digitsOnly = RegExp(r'^\d+$');

/// Returns an error message, or null when the PIN length is acceptable.
String? validateVaultPin(String pin) {
  if (pin.length < vaultPinMinLength || pin.length > vaultPinMaxLength) {
    return 'Must be $vaultPinMinLength-$vaultPinMaxLength characters.';
  }
  return null;
}

/// A soft security warning for weak vault secrets. Short and/or digits-only
/// values are the most guessable; returns null once reasonably strong.
String? getWeakPinWarning(String pin) {
  if (pin.length < vaultPinMinLength) return null; // handled by validation

  if (_digitsOnly.hasMatch(pin) && pin.length < 8) {
    return 'A ${pin.length}-digit PIN is easy to guess. Use 8+ digits, or add '
        'letters and symbols for much stronger protection.';
  }
  if (pin.length < 6) {
    return 'This is short. A longer PIN or passphrase (letters, numbers, '
        'symbols) is much harder to guess.';
  }
  return null;
}
