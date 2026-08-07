import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// True when [e] looks like a connectivity failure (offline, DNS, timeout)
/// rather than a server-side rejection.
bool isNetworkError(Object e) {
  if (e is SocketException) return true;
  final s = e.toString();
  return s.contains('SocketException') ||
      s.contains('Failed host lookup') ||
      s.contains('Connection') ||
      s.contains('ClientException') ||
      s.contains('TimeoutException');
}

/// A user-facing message for a failed write. Connectivity problems get the
/// "check your connection" hint; anything else (constraint violations, RLS,
/// bad requests) surfaces the server's actual message so the failure is
/// diagnosable instead of masked behind a generic connection error.
String saveErrorMessage(Object e) {
  if (isNetworkError(e)) return "Couldn't save. Check your connection.";
  if (e is PostgrestException) return "Couldn't save: ${e.message}";
  if (e is AuthException) return "Couldn't save: ${e.message}";
  return "Couldn't save. Please try again.";
}
