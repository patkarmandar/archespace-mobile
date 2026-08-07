import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:archespace_mobile/src/features/items/domain/item_types.dart';
import 'package:archespace_mobile/src/shared/crypto/arche_crypto.dart';

/// JSON backup export/import, compatible with the web backup format:
/// a top-level array of decrypted spaces, each with an `items` array of
/// decrypted items ({ type, title, content, position, pinned }).
class BackupRepository {
  BackupRepository(this._masterKey);

  final List<int> _masterKey;

  SupabaseClient get _client => Supabase.instance.client;

  Future<String> _dec(Object? v) =>
      ArcheCrypto.decryptArc1((v ?? '') as String, _masterKey);
  Future<String> _enc(String v) => ArcheCrypto.encryptArc1(v, _masterKey);
  Future<String> _encJson(Object? v) =>
      ArcheCrypto.encryptArc1(jsonEncode(v), _masterKey);

  Future<List<String>> _decTags(Object? raw) async {
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String && raw.isNotEmpty) {
      final text = raw.startsWith('arc1:') ? await _dec(raw) : raw;
      try {
        final d = jsonDecode(text);
        if (d is List) return d.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    return const [];
  }

  Future<Map<String, dynamic>> _decContent(Object? raw) async {
    if (raw is Map) return raw.cast<String, dynamic>();
    if (raw is String && raw.isNotEmpty) {
      final text = await _dec(raw);
      if (text.isEmpty) return {};
      final d = jsonDecode(text);
      if (d is Map) return d.cast<String, dynamic>();
    }
    return {};
  }

  /// Build the backup JSON (active spaces + items, decrypted).
  Future<String> exportJson() async {
    final spaceRows = await _client
        .from('spaces')
        .select('id, name, description, tags, color, pinned, position')
        .isFilter('deleted_at', null)
        .isFilter('archived_at', null)
        .order('position');

    final out = <Map<String, dynamic>>[];
    for (final s in spaceRows) {
      final itemRows = await _client
          .from('space_items')
          .select('type, title, content, position, pinned')
          .eq('space_id', s['id'] as String)
          .isFilter('deleted_at', null)
          .isFilter('archived_at', null)
          .order('position');

      final items = <Map<String, dynamic>>[];
      for (final it in itemRows) {
        items.add({
          'type': it['type'],
          'title': await _dec(it['title']),
          'content': await _decContent(it['content']),
          'position': it['position'],
          'pinned': it['pinned'] ?? false,
        });
      }

      out.add({
        'name': await _dec(s['name']),
        'description': await _dec(s['description']),
        'color': s['color'],
        'tags': await _decTags(s['tags']),
        'pinned': s['pinned'] ?? false,
        'position': s['position'],
        'items': items,
      });
    }
    return const JsonEncoder.withIndent('  ').convert(out);
  }

  /// Import a backup: encrypt and insert new spaces + items. Returns the number
  /// of items imported. Unknown item types / malformed content are skipped.
  Future<int> importJson(String text) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Not authenticated');

    final parsed = jsonDecode(text);
    if (parsed is! List) {
      throw const FormatException('Expected a JSON array of spaces.');
    }

    final existing = await _client
        .from('spaces')
        .select('id')
        .isFilter('deleted_at', null)
        .isFilter('archived_at', null);
    var spacePos = existing.length;

    final knownTypes = kItemTypes.map((d) => d.type).toSet();
    var itemsImported = 0;

    for (final raw in parsed) {
      if (raw is! Map) continue;

      final rawName = raw['name'];
      final name = (rawName is String && rawName.trim().isNotEmpty)
          ? rawName.trim()
          : 'Imported Space';
      final description = raw['description'] is String
          ? (raw['description'] as String).trim()
          : '';
      final color = raw['color'] is String ? raw['color'] as String : null;
      final tags = raw['tags'] is List
          ? (raw['tags'] as List).map((e) => e.toString()).toList()
          : <String>[];

      final created = await _client
          .from('spaces')
          .insert({
            'user_id': userId,
            'name': await _enc(name),
            'description': await _enc(description),
            'color': color,
            'tags': tags.isEmpty ? null : await _encJson(tags),
            'position': spacePos++,
          })
          .select('id')
          .single();
      final spaceId = created['id'] as String;

      final items = raw['items'];
      if (items is! List) continue;

      final rows = <Map<String, dynamic>>[];
      for (final it in items) {
        if (it is! Map) continue;
        final type = it['type'];
        if (type is! String || !knownTypes.contains(type)) continue;
        final content = it['content'];
        if (content is! Map) continue;
        final title = it['title'] is String
            ? (it['title'] as String).trim()
            : '';
        rows.add({
          'space_id': spaceId,
          'type': type,
          'title': await _enc(title),
          'content': await _encJson(content),
          'position': it['position'] is int ? it['position'] : rows.length,
          'pinned': it['pinned'] == true,
        });
      }
      if (rows.isNotEmpty) {
        await _client.from('space_items').insert(rows);
        itemsImported += rows.length;
      }
    }
    return itemsImported;
  }
}
