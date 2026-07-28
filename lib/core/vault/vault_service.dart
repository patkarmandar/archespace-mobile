import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../crypto/arche_crypto.dart';

class VaultException implements Exception {
  VaultException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Fetches the user's `user_encryption` row and unlocks the vault, mirroring the
/// web `unlockPinWrappedVault` flow (see spec/crypto-format.md section 4).
class VaultService {
  SupabaseClient get _client => Supabase.instance.client;

  static const String _checkPlaintext = 'ARCHE_VAULT_V1_OK';

  Future<bool> hasVault(String userId) async {
    final row = await _client
        .from('user_encryption')
        .select('user_id')
        .eq('user_id', userId)
        .maybeSingle();
    return row != null;
  }

  /// Derive the PIN key, unwrap the master key, and verify it. Returns the raw
  /// master key on success; throws [VaultException] on a wrong PIN / no vault.
  Future<Uint8List> unlock(String userId, String pin) async {
    final meta = await _client
        .from('user_encryption')
        .select('salt, key_check, wrapped_key')
        .eq('user_id', userId)
        .maybeSingle();

    if (meta == null) {
      throw VaultException('No vault PIN is configured for this account.');
    }

    final pinKey = await ArcheCrypto.deriveVaultKey(pin, meta['salt'] as String);

    String rawKeyB64;
    try {
      rawKeyB64 =
          await ArcheCrypto.decryptArc1(meta['wrapped_key'] as String, pinKey);
    } catch (_) {
      // A wrong PIN makes GCM authentication fail before the key check.
      throw VaultException('Incorrect PIN.');
    }

    final masterKey = base64.decode(rawKeyB64);
    final check =
        await ArcheCrypto.decryptArc1(meta['key_check'] as String, masterKey);
    if (check != _checkPlaintext) {
      throw VaultException('Incorrect PIN.');
    }
    return Uint8List.fromList(masterKey);
  }
}
