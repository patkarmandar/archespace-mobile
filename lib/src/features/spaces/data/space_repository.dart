import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:archespace_mobile/src/features/spaces/domain/space.dart';
import 'package:archespace_mobile/src/shared/crypto/arche_crypto.dart';
import 'package:archespace_mobile/src/shared/data/cache_store.dart';
import 'package:archespace_mobile/src/shared/offline/write_queue.dart';

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
          .select(
            'id, name, description, tags, color, pinned, position, created_at',
          )
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
      WriteQueue.instance.flush(); // network is up: drain any queued writes
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
      spaces.add(
        Space(
          id: m['id'] as String,
          name: await ArcheCrypto.decryptArc1(
            (m['name'] ?? '') as String,
            _masterKey,
          ),
          description: await ArcheCrypto.decryptArc1(
            (m['description'] ?? '') as String,
            _masterKey,
          ),
          pinned: (m['pinned'] ?? false) as bool,
          tags: await _decodeTags(m['tags']),
          color: m['color'] as String?,
          itemCount: (m['_item_count'] ?? 0) as int,
          pinnedCount: (m['_pinned_count'] ?? 0) as int,
          createdAt: DateTime.tryParse((m['created_at'] ?? '').toString()),
        ),
      );
    }
    return spaces;
  }

  Future<List<String>> _decodeTags(Object? raw) async {
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String && raw.isNotEmpty) {
      final text = raw.startsWith('arc1:')
          ? await ArcheCrypto.decryptArc1(raw, _masterKey)
          : raw;
      try {
        final decoded = jsonDecode(text);
        if (decoded is List) return decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    return const [];
  }

  Future<String> _enc(String value) =>
      ArcheCrypto.encryptArc1(value, _masterKey);

  Future<String> _encTags(List<String> tags) =>
      ArcheCrypto.encryptArc1(jsonEncode(tags), _masterKey);

  /// Duplicate a space and all its (non-deleted, non-archived) items. Item
  /// ciphertext is copied verbatim — it's already encrypted with the same key.
  Future<void> duplicateSpace(Space space) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Not authenticated');

    final existing = await _client
        .from('spaces')
        .select('id')
        .isFilter('deleted_at', null)
        .isFilter('archived_at', null);

    final payload = <String, dynamic>{
      'user_id': userId,
      'name': await _enc('${space.name} (copy)'),
      'description': await _enc(space.description),
      'color': space.color,
      'position': existing.length,
    };
    if (space.tags.isNotEmpty) payload['tags'] = await _encTags(space.tags);

    final created = await _client
        .from('spaces')
        .insert(payload)
        .select('id')
        .single();
    final newId = created['id'] as String;

    final srcItems = await _client
        .from('space_items')
        .select('type, title, content, position, pinned')
        .eq('space_id', space.id)
        .isFilter('deleted_at', null)
        .isFilter('archived_at', null);

    if (srcItems.isNotEmpty) {
      final rows = [
        for (final it in srcItems)
          {
            'space_id': newId,
            'type': it['type'],
            'title': it['title'],
            'content': it['content'],
            'position': it['position'],
            'pinned': it['pinned'] ?? false,
          },
      ];
      await _client.from('space_items').insert(rows);
    }
  }

  /// Create a new space at the end of the list (position = current count).
  Future<void> createSpace({
    required String name,
    String description = '',
    String? color,
    List<String> tags = const [],
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
      'color': color,
      // `tags` is jsonb NOT NULL; always store an encrypted array (matching the
      // web) rather than null, which would violate the constraint.
      'tags': await _encTags(tags),
      'position': existing.length,
    });
  }

  Future<void> updateSpace({
    required String id,
    required String name,
    String description = '',
    String? color,
    List<String> tags = const [],
  }) async {
    await _client
        .from('spaces')
        .update({
          'name': await _enc(name),
          'description': await _enc(description),
          'color': color,
          // `tags` is jsonb NOT NULL; store an encrypted array, never null.
          'tags': await _encTags(tags),
        })
        .eq('id', id);
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

  String _nowIso() => DateTime.now().toUtc().toIso8601String();

  /// Persist a new order (positions 0..N-1) via the batch RPC.
  Future<void> reorder(List<String> orderedIds) async {
    final updates = [
      for (var i = 0; i < orderedIds.length; i++)
        {'id': orderedIds[i], 'position': i},
    ];
    await _client.rpc('update_space_positions', params: {'updates': updates});
  }

  Future<void> bulkSetPinned(List<String> ids, bool pinned) async {
    if (ids.isEmpty) return;
    await _client.from('spaces').update({'pinned': pinned}).inFilter('id', ids);
  }

  Future<void> bulkArchive(List<String> ids) async {
    if (ids.isEmpty) return;
    await _client
        .from('spaces')
        .update({'archived_at': _nowIso()})
        .inFilter('id', ids);
  }

  Future<void> bulkDelete(List<String> ids) async {
    if (ids.isEmpty) return;
    await _client
        .from('spaces')
        .update({'deleted_at': _nowIso()})
        .inFilter('id', ids);
  }

  /// Soft-delete to the recycle bin (sets deleted_at), matching the web.
  Future<void> deleteSpace(String id) async {
    await _client
        .from('spaces')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }
}
