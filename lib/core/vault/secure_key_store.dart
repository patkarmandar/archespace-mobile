import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the vault master key in the platform keystore (Android Keystore /
/// iOS Keychain) so the vault can be reopened with biometrics instead of the
/// PIN. Stored base64-encoded; the storage layer encrypts it at rest.
class SecureKeyStore {
  static const String _keyName = 'vault_master_key';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  Future<bool> hasKey() async {
    return (await _storage.read(key: _keyName)) != null;
  }

  Future<void> saveMasterKey(List<int> key) async {
    await _storage.write(key: _keyName, value: base64.encode(key));
  }

  Future<Uint8List?> readMasterKey() async {
    final value = await _storage.read(key: _keyName);
    if (value == null) return null;
    return Uint8List.fromList(base64.decode(value));
  }

  Future<void> clear() async {
    await _storage.delete(key: _keyName);
  }
}
