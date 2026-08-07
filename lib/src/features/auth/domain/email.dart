/// Email validation for the sign-in and sign-up forms.
///
/// Accepts the ordinary set of email characters (letters, digits, and
/// `. _ % + -` in the local part) and a dotted domain with a 2+ letter TLD.
/// Anything else - spaces or stray special characters like `! # $ ^ & *` - is
/// rejected before the request reaches Supabase.
library;

final RegExp _emailPattern = RegExp(
  r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
);

/// Returns an error message, or null when [email] looks like a valid address.
/// Trim before calling.
String? validateEmail(String email) {
  if (email.isEmpty) return 'Enter your email address.';
  if (email.contains(' ')) return 'Email cannot contain spaces.';
  if (!_emailPattern.hasMatch(email)) return 'Enter a valid email address.';
  return null;
}
