import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:archespace_mobile/src/features/items/domain/space_item.dart';
import 'package:archespace_mobile/src/shared/crypto/arche_crypto.dart';
import 'package:archespace_mobile/src/shared/data/cache_store.dart';

/// Reads and decrypts the items in a space. The `title` column is an `arc1`
/// string and `content` is `arc1(JSON.stringify(obj))`; everything else is
/// plain metadata. Mirrors the web `decryptItem` + default ordering.
class ItemRepository {
  ItemRepository(this._masterKey);

  final List<int> _masterKey;

  SupabaseClient get _client => Supabase.instance.client;

  /// Fetch a space's items, caching the encrypted rows; on a network error,
  /// fall back to the cache. `fromCache` is true when the fallback was used.
  Future<({List<SpaceItem> items, bool fromCache})> listItems(
      String spaceId) async {
    final cacheKey = 'items_$spaceId';
    List<dynamic> rows;
    try {
      rows = await _client
          .from('space_items')
          .select('id, type, title, content, pinned, position, created_at')
          .eq('space_id', spaceId)
          .isFilter('deleted_at', null)
          .isFilter('archived_at', null)
          .order('pinned', ascending: false)
          .order('position', ascending: true);
      await CacheStore.write(cacheKey, rows);
    } catch (_) {
      final cached = await CacheStore.read(cacheKey);
      if (cached is List) {
        return (items: await _decode(cached), fromCache: true);
      }
      rethrow;
    }
    return (items: await _decode(rows), fromCache: false);
  }

  Future<List<SpaceItem>> _decode(List<dynamic> rows) async {
    final items = <SpaceItem>[];
    for (final row in rows) {
      final m = row as Map;
      items.add(SpaceItem(
        id: m['id'] as String,
        type: (m['type'] ?? '') as String,
        title: await ArcheCrypto.decryptArc1(
            (m['title'] ?? '') as String, _masterKey),
        content: await _decryptContent(m['content']),
        pinned: (m['pinned'] ?? false) as bool,
      ));
    }
    return items;
  }

  Future<Map<String, dynamic>> _decryptContent(Object? raw) async {
    if (raw is Map) return raw.cast<String, dynamic>();
    if (raw is String && raw.isNotEmpty) {
      final text = await ArcheCrypto.decryptArc1(raw, _masterKey);
      if (text.isEmpty) return <String, dynamic>{};
      final decoded = jsonDecode(text);
      if (decoded is Map) return decoded.cast<String, dynamic>();
    }
    return <String, dynamic>{};
  }

  Future<String> _encTitle(String title) =>
      ArcheCrypto.encryptArc1(title, _masterKey);

  Future<String> _encContent(Map<String, dynamic> content) =>
      ArcheCrypto.encryptArc1(jsonEncode(content), _masterKey);

  /// Re-encrypt and save an existing item's title + content.
  Future<void> updateItem({
    required String id,
    required String title,
    required Map<String, dynamic> content,
  }) async {
    await _client.from('space_items').update({
      'title': await _encTitle(title),
      'content': await _encContent(content),
    }).eq('id', id);
  }

  Future<void> setPinned(String id, bool pinned) async {
    await _client.from('space_items').update({'pinned': pinned}).eq('id', id);
  }

  Future<void> archiveItem(String id) async {
    await _client
        .from('space_items')
        .update({'archived_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  Future<void> deleteItem(String id) async {
    await _client
        .from('space_items')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  Future<int> _endPosition(String spaceId) async {
    final existing = await _client
        .from('space_items')
        .select('id')
        .eq('space_id', spaceId)
        .isFilter('deleted_at', null)
        .isFilter('archived_at', null);
    return existing.length;
  }

  Future<void> duplicateItem(String spaceId, SpaceItem item) async {
    final title = item.title.isEmpty ? 'Untitled (copy)' : '${item.title} (copy)';
    await _client.from('space_items').insert({
      'space_id': spaceId,
      'type': item.type,
      'title': await _encTitle(title),
      'content': await _encContent(item.content),
      'position': await _endPosition(spaceId),
    });
  }

  Future<void> moveItem(String itemId, String targetSpaceId) async {
    await _client.from('space_items').update({
      'space_id': targetSpaceId,
      'position': await _endPosition(targetSpaceId),
      'pinned': false,
    }).eq('id', itemId);
  }

  String _nowIso() => DateTime.now().toUtc().toIso8601String();

  Future<void> bulkSetPinned(List<String> ids, bool pinned) async {
    if (ids.isEmpty) return;
    await _client
        .from('space_items')
        .update({'pinned': pinned}).inFilter('id', ids);
  }

  Future<void> bulkArchive(List<String> ids) async {
    if (ids.isEmpty) return;
    await _client
        .from('space_items')
        .update({'archived_at': _nowIso()}).inFilter('id', ids);
  }

  Future<void> bulkDelete(List<String> ids) async {
    if (ids.isEmpty) return;
    await _client
        .from('space_items')
        .update({'deleted_at': _nowIso()}).inFilter('id', ids);
  }

  Future<void> bulkMove(List<String> ids, String targetSpaceId) async {
    var position = await _endPosition(targetSpaceId);
    for (final id in ids) {
      await _client.from('space_items').update({
        'space_id': targetSpaceId,
        'position': position,
        'pinned': false,
      }).eq('id', id);
      position++;
    }
  }

  /// Create a new item at the end of the space (position = current count).
  Future<void> createItem({
    required String spaceId,
    required String type,
    String title = '',
    required Map<String, dynamic> content,
  }) async {
    final existing = await _client
        .from('space_items')
        .select('id')
        .eq('space_id', spaceId)
        .isFilter('deleted_at', null)
        .isFilter('archived_at', null);

    await _client.from('space_items').insert({
      'space_id': spaceId,
      'type': type,
      'title': await _encTitle(title),
      'content': await _encContent(content),
      'position': existing.length,
    });
  }
}
