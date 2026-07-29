import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:archespace_mobile/src/features/spaces/domain/space.dart';
import 'package:archespace_mobile/src/shared/crypto/arche_crypto.dart';

/// Reads spaces from Supabase and decrypts them with the master key. Encrypted
/// columns (`name`, `description`) are `arc1` values; everything else is plain
/// metadata. Mirrors the web `decryptSpace` + default ordering.
class SpaceRepository {
  SpaceRepository(this._masterKey);

  final List<int> _masterKey;

  SupabaseClient get _client => Supabase.instance.client;

  Future<List<Space>> listSpaces() async {
    final rows = await _client
        .from('spaces')
        .select('id, name, description, pinned, position, created_at')
        .isFilter('deleted_at', null)
        .isFilter('archived_at', null)
        .order('pinned', ascending: false)
        .order('position', ascending: true)
        .order('created_at', ascending: false);

    final spaces = <Space>[];
    for (final row in rows) {
      spaces.add(Space(
        id: row['id'] as String,
        name: await ArcheCrypto.decryptArc1(
            (row['name'] ?? '') as String, _masterKey),
        description: await ArcheCrypto.decryptArc1(
            (row['description'] ?? '') as String, _masterKey),
        pinned: (row['pinned'] ?? false) as bool,
      ));
    }
    return spaces;
  }
}
