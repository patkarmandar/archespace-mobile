import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../crypto/arche_crypto.dart';
import 'space_item.dart';

/// Reads and decrypts the items in a space. The `title` column is an `arc1`
/// string and `content` is `arc1(JSON.stringify(obj))`; everything else is
/// plain metadata. Mirrors the web `decryptItem` + default ordering.
class ItemRepository {
  ItemRepository(this._masterKey);

  final List<int> _masterKey;

  SupabaseClient get _client => Supabase.instance.client;

  Future<List<SpaceItem>> listItems(String spaceId) async {
    final rows = await _client
        .from('space_items')
        .select('id, type, title, content, pinned, position, created_at')
        .eq('space_id', spaceId)
        .isFilter('deleted_at', null)
        .isFilter('archived_at', null)
        .order('pinned', ascending: false)
        .order('position', ascending: true);

    final items = <SpaceItem>[];
    for (final row in rows) {
      items.add(SpaceItem(
        id: row['id'] as String,
        type: (row['type'] ?? '') as String,
        title: await ArcheCrypto.decryptArc1(
            (row['title'] ?? '') as String, _masterKey),
        content: await _decryptContent(row['content']),
        pinned: (row['pinned'] ?? false) as bool,
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
