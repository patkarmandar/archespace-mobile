import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:archespace_mobile/src/shared/crypto/arche_crypto.dart';

/// One searchable entry: either a space or an item. [haystack] is the
/// lowercased text matched against; the rest is for display/navigation.
class SearchHit {
  SearchHit({
    required this.isSpace,
    required this.id,
    required this.spaceId,
    required this.spaceName,
    required this.title,
    required this.type,
    required this.haystack,
  });

  final bool isSpace;
  final String id;
  final String spaceId;
  final String spaceName;
  final String title;
  final String type;
  final String haystack;
}

/// Loads and decrypts every space + item into a flat search index. Mirrors the
/// web global search: spaces match on name/description/tags; items match on
/// title + type-specific content text. Secret content stays sealed (title only).
class SearchRepository {
  SearchRepository(this._masterKey);

  final List<int> _masterKey;

  SupabaseClient get _client => Supabase.instance.client;

  Future<List<SearchHit>> loadIndex() async {
    final spaceRows = await _client
        .from('spaces')
        .select('id, name, description, tags')
        .isFilter('deleted_at', null)
        .isFilter('archived_at', null);

    final hits = <SearchHit>[];
    final spaceNameById = <String, String>{};

    for (final row in spaceRows) {
      final id = row['id'] as String;
      final name = await ArcheCrypto.decryptArc1(
        (row['name'] ?? '') as String,
        _masterKey,
      );
      final description = await ArcheCrypto.decryptArc1(
        (row['description'] ?? '') as String,
        _masterKey,
      );
      final tags = await _decodeTags(row['tags']);
      spaceNameById[id] = name;
      hits.add(
        SearchHit(
          isSpace: true,
          id: id,
          spaceId: id,
          spaceName: name,
          title: name,
          type: 'space',
          haystack: '$name $description ${tags.join(' ')}'.toLowerCase(),
        ),
      );
    }

    final itemRows = await _client
        .from('space_items')
        .select('id, space_id, type, title, content')
        .isFilter('deleted_at', null)
        .isFilter('archived_at', null);

    for (final row in itemRows) {
      final type = (row['type'] ?? '') as String;
      final title = await ArcheCrypto.decryptArc1(
        (row['title'] ?? '') as String,
        _masterKey,
      );
      final content = await _decodeContent(row['content']);
      final spaceId = row['space_id'] as String;
      hits.add(
        SearchHit(
          isSpace: false,
          id: row['id'] as String,
          spaceId: spaceId,
          spaceName: spaceNameById[spaceId] ?? '',
          title: title,
          type: type,
          haystack: _itemText(type, title, content).toLowerCase(),
        ),
      );
    }

    return hits;
  }

  Future<Map<String, dynamic>> _decodeContent(Object? raw) async {
    if (raw is Map) return raw.cast<String, dynamic>();
    if (raw is String && raw.isNotEmpty) {
      final text = await ArcheCrypto.decryptArc1(raw, _masterKey);
      if (text.isEmpty) return {};
      final decoded = jsonDecode(text);
      if (decoded is Map) return decoded.cast<String, dynamic>();
    }
    return {};
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
    return [];
  }
}

/// Type-specific searchable text (title + content). Secret/drawing add nothing
/// beyond the title.
String _itemText(String type, String title, Map<String, dynamic> content) {
  final parts = <String>[title];
  switch (type) {
    case 'textbox':
    case 'markdown':
      parts.add((content['text'] ?? '').toString());
    case 'menu_list':
    case 'numbered_list':
    case 'checkbox_list':
      for (final it in (content['items'] as List? ?? const [])) {
        if (it is Map) parts.add((it['text'] ?? '').toString());
      }
    case 'card_list':
      for (final it in (content['items'] as List? ?? const [])) {
        if (it is Map) {
          parts.add((it['title'] ?? '').toString());
          parts.add((it['description'] ?? '').toString());
        }
      }
    case 'table':
      for (final c in (content['columns'] as List? ?? const [])) {
        parts.add((c ?? '').toString());
      }
      for (final r in (content['rows'] as List? ?? const [])) {
        if (r is List) {
          for (final cell in r) {
            parts.add((cell ?? '').toString());
          }
        }
      }
  }
  return parts.join(' ');
}
