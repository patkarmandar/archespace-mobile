import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:archespace_mobile/src/features/items/domain/item_types.dart';
import 'package:archespace_mobile/src/shared/crypto/arche_crypto.dart';

/// JSON backup export/import, matching the web format: a versioned envelope
/// `{ app, version, exportedAt, spaces: [...] }` where each space carries its
/// decrypted fields and an `items` array of decrypted items ({ type, title,
/// content, position, pinned }). Import also accepts the older bare-array format.
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
    final payload = {
      'app': 'ArcheSpace',
      'version': 2,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'spaces': out,
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Import a backup: encrypt and insert new spaces + items. Accepts the current
  /// `{ version, spaces: [...] }` format and the older bare-array format.
  /// Returns how many spaces and items were imported, and how many items were
  /// skipped (unknown type / malformed content).
  Future<({int spaces, int items, int skipped})> importJson(String text) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Not authenticated');

    final parsed = jsonDecode(text);
    // Current format is { version, spaces: [...] }; older backups are a bare list.
    final List<dynamic> parsedSpaces;
    if (parsed is List) {
      parsedSpaces = parsed;
    } else if (parsed is Map && parsed['spaces'] is List) {
      parsedSpaces = parsed['spaces'] as List;
    } else {
      throw const FormatException('Expected a list of spaces.');
    }

    final existing = await _client
        .from('spaces')
        .select('id')
        .isFilter('deleted_at', null)
        .isFilter('archived_at', null);
    var spacePos = existing.length;

    final knownTypes = kItemTypes.map((d) => d.type).toSet();
    var itemsImported = 0;
    var itemsSkipped = 0;
    var spacesImported = 0;

    for (final raw in parsedSpaces) {
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
            'pinned': raw['pinned'] == true,
            'position': spacePos++,
          })
          .select('id')
          .single();
      final spaceId = created['id'] as String;
      spacesImported++;

      final items = raw['items'];
      if (items is! List) continue;

      final rows = <Map<String, dynamic>>[];
      for (final it in items) {
        if (it is! Map) {
          itemsSkipped++;
          continue;
        }
        final type = it['type'];
        if (type is! String || !knownTypes.contains(type)) {
          itemsSkipped++;
          continue;
        }
        final content = it['content'];
        if (content is! Map) {
          itemsSkipped++;
          continue;
        }
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
    return (
      spaces: spacesImported,
      items: itemsImported,
      skipped: itemsSkipped,
    );
  }
}
