import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:archespace_mobile/src/features/vault/domain/recovery_code.dart';
import 'package:archespace_mobile/src/shared/config/app_config.dart';

/// Data returned when starting TOTP enrolment.
class MfaEnrollment {
  MfaEnrollment({
    required this.factorId,
    required this.secret,
    required this.uri,
  });

  final String factorId;
  final String secret;
  final String uri;
}

/// Two-factor auth (TOTP) via Supabase MFA, plus recoverable backup codes.
///
/// Mirrors the web `lib/mfa.js`. The TOTP secret lives only in Supabase's
/// auth.mfa_factors (never in a client-readable table), so 2FA still protects
/// the account if the login password leaks. Backup codes reuse the vault
/// recovery-code format; only their SHA-256 hash is stored, matching the
/// `redeem_mfa_backup_code` function in schema.sql section 4b.
class MfaService {
  static const int backupCodeCount = 8;

  SupabaseClient get _client => Supabase.instance.client;

  Future<String> _sha256Hex(String text) async {
    final digest = await Sha256().hash(utf8.encode(text));
    return digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Begin TOTP enrolment. Clears any unverified leftovers first so Supabase
  /// doesn't reject the new factor on a duplicate friendly name.
  Future<MfaEnrollment> enroll() async {
    final list = await _client.auth.mfa.listFactors();
    for (final f in list.all.where((f) => f.status != FactorStatus.verified)) {
      try {
        await _client.auth.mfa.unenroll(f.id);
      } catch (_) {
        // Ignore: a leftover we couldn't remove won't block a fresh enrol.
      }
    }
    final res = await _client.auth.mfa.enroll(
      factorType: FactorType.totp,
      friendlyName: 'Authenticator ${DateTime.now().millisecondsSinceEpoch}',
    );
    final totp = res.totp!;
    return MfaEnrollment(factorId: res.id, secret: totp.secret, uri: totp.uri);
  }

  /// Verify a 6-digit code for a factor. Elevates the session to AAL2.
  Future<void> verify(String factorId, String code) async {
    await _client.auth.mfa.challengeAndVerify(
      factorId: factorId,
      code: code.trim(),
    );
  }

  Future<void> unenroll(String factorId) async {
    await _client.auth.mfa.unenroll(factorId);
  }

  /// The user's verified TOTP factor id, or null if 2FA is off.
  Future<String?> verifiedFactorId() async {
    final list = await _client.auth.mfa.listFactors();
    for (final f in list.totp) {
      if (f.status == FactorStatus.verified) return f.id;
    }
    return null;
  }

  /// True while the session has passed the password but not yet 2FA.
  bool needsChallenge() {
    final aal = _client.auth.mfa.getAuthenticatorAssuranceLevel();
    return aal.currentLevel == AuthenticatorAssuranceLevels.aal1 &&
        aal.nextLevel == AuthenticatorAssuranceLevels.aal2;
  }

  /// Replace the user's backup codes. Returns the plaintext codes to show once.
  Future<List<String>> regenerateBackupCodes(String userId) async {
    final codes = List.generate(backupCodeCount, (_) => generateRecoveryCode());
    final rows = <Map<String, dynamic>>[];
    for (final code in codes) {
      rows.add({
        'user_id': userId,
        'code_hash': await _sha256Hex(normalizeRecoveryCode(code)),
      });
    }
    await _client.from('mfa_backup_codes').delete().eq('user_id', userId);
    await _client.from('mfa_backup_codes').insert(rows);
    return codes;
  }

  /// How many unused backup codes remain.
  Future<int> countUnusedBackupCodes() async {
    final rows = await _client
        .from('mfa_backup_codes')
        .select('id')
        .isFilter('used_at', null);
    return (rows as List).length;
  }

  /// Redeem a backup code from an AAL1 session. On success 2FA is removed.
  Future<bool> redeemBackupCode(String code) async {
    final result = await _client.rpc(
      'redeem_mfa_backup_code',
      params: {'code': code},
    );
    return result == true;
  }

  /// Check the account password without disturbing the active session. Signing
  /// in on the shared client would drop a 2FA user below AAL2 (which unenroll
  /// needs), so this uses a throwaway client that never persists a session.
  Future<bool> verifyAccountPassword(String email, String password) async {
    final probe = SupabaseClient(
      AppConfig.supabaseUrl,
      AppConfig.supabaseAnonKey,
    );
    try {
      await probe.auth.signInWithPassword(email: email, password: password);
      return true;
    } catch (_) {
      return false;
    } finally {
      try {
        await probe.auth.signOut(scope: SignOutScope.local);
      } catch (_) {
        // Ignore sign-out failures on the throwaway client.
      }
      await probe.dispose();
    }
  }
}
