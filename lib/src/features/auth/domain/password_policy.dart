/// Login password strength rules, ported from the web `passwordPolicy.js`.
library;

const int passwordMinLength = 8;

/// Returns an error message, or null when the password meets the policy.
String? validatePassword(String password) {
  if (password.length < passwordMinLength) {
    return 'Password must be at least $passwordMinLength characters.';
  }
  if (!RegExp('[A-Z]').hasMatch(password)) {
    return 'Password must include at least one uppercase letter.';
  }
  if (!RegExp('[a-z]').hasMatch(password)) {
    return 'Password must include at least one lowercase letter.';
  }
  if (!RegExp(r'\d').hasMatch(password)) {
    return 'Password must include at least one number.';
  }
  return null;
}
