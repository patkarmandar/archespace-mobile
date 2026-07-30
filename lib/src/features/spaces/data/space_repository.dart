import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:archespace_mobile/src/features/spaces/domain/space.dart';
import 'package:archespace_mobile/src/shared/crypto/arche_crypto.dart';
import 'package:archespace_mobile/src/shared/data/cache_store.dart';

/// Reads spaces from Supabase and decrypts them with the master key. Encrypted
/// columns (`name`, `description`) are `arc1` values; everything else is plain
/// metadata. Mirrors the web `decryptSpace` + default ordering.
class SpaceRepository {
  SpaceRepository(this._masterKey);

  final List<int> _masterKey;

  SupabaseClient get _client => Supabase.instance.client;

  /// Fetch spaces, caching the encrypted rows; on a network error, fall back
  /// to the cache. `fromCache` is true when the offline fallback was used.
  Future<({List<Space> spaces, bool fromCache})> listSpaces() async {
    const cacheKey = 'spaces';
    List<dynamic> rows;
    try {
      rows = await _client
          .from('spaces')
          .select('id, name, description, tags, color, pinned, position, created_at')
          .isFilter('deleted_at', null)
          .isFilter('archived_at', null)
          .order('pinned', ascending: false)
          .order('position', ascending: true)
          .order('created_at', ascending: false);

      // Per-space item counts (lightweight: no titles/content).
      final itemRows = await _client
          .from('space_items')
          .select('space_id, pinned')
          .isFilter('deleted_at', null)
          .isFilter('archived_at', null);
      final total = <String, int>{};
      final pinned = <String, int>{};
      for (final r in itemRows) {
        final sid = r['space_id'] as String;
        total[sid] = (total[sid] ?? 0) + 1;
        if (r['pinned'] == true) pinned[sid] = (pinned[sid] ?? 0) + 1;
      }
      for (final r in rows) {
        final m = r as Map<String, dynamic>;
        m['_item_count'] = total[m['id']] ?? 0;
        m['_pinned_count'] = pinned[m['id']] ?? 0;
      }
      await CacheStore.write(cacheKey, rows);
    } catch (_) {
      final cached = await CacheStore.read(cacheKey);
      if (cached is List) {
        return (spaces: await _decode(cached), fromCache: true);
      }
      rethrow;
    }
    return (spaces: await _decode(rows), fromCache: false);
  }

  Future<List<Space>> _decode(List<dynamic> rows) async {
    final spaces = <Space>[];
    for (final row in rows) {
      final m = row as Map;
      spaces.add(Space(
        id: m['id'] as String,
        name: await ArcheCrypto.decryptArc1(
            (m['name'] ?? '') as String, _masterKey),
        description: await ArcheCrypto.decryptArc1(
            (m['description'] ?? '') as String, _masterKey),
        pinned: (m['pinned'] ?? false) as bool,
        tags: await _decodeTags(m['tags']),
        color: m['color'] as String?,
        itemCount: (m['_item_count'] ?? 0) as int,
        pinnedCount: (m['_pinned_count'] ?? 0) as int,
      ));
    }
    return spaces;
  }

  Future<List<String>> _decodeTags(Object? raw) async {
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String && raw.isNotEmpty) {
      final text =
          raw.startsWith('arc1:') ? await ArcheCrypto.decryptArc1(raw, _masterKey) : raw;
      try {
        final decoded = jsonDecode(text);
        if (decoded is List) return decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    return const [];
  }

  Future<String> _enc(String value) =>
      ArcheCrypto.encryptArc1(value, _masterKey);

  /// Create a new space at the end of the list (position = current count).
  Future<void> createSpace({
    required String name,
    String description = '',
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Not authenticated');

    final existing = await _client
        .from('spaces')
        .select('id')
        .isFilter('deleted_at', null)
        .isFilter('archived_at', null);

    await _client.from('spaces').insert({
      'user_id': userId,
      'name': await _enc(name),
      'description': await _enc(description),
      'position': existing.length,
    });
  }

  /// Update only the name + description; other columns (tags, color, pinned)
  /// are left untouched.
  Future<void> updateSpace({
    required String id,
    required String name,
    String description = '',
  }) async {
    await _client.from('spaces').update({
      'name': await _enc(name),
      'description': await _enc(description),
    }).eq('id', id);
  }

  Future<void> setPinned(String id, bool pinned) async {
    await _client.from('spaces').update({'pinned': pinned}).eq('id', id);
  }

  Future<void> archiveSpace(String id) async {
    await _client
        .from('spaces')
        .update({'archived_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  /// Soft-delete to the recycle bin (sets deleted_at), matching the web.
  Future<void> deleteSpace(String id) async {
    await _client
        .from('spaces')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }
}
