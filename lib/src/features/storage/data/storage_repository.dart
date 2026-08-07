import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:archespace_mobile/src/shared/crypto/arche_crypto.dart';

/// A space or item that is archived or in the recycle bin.
class StoredEntry {
  StoredEntry({
    required this.id,
    required this.label,
    required this.isSpace,
    required this.type,
  });

  final String id;
  final String label;
  final bool isSpace;
  final String type; // 'space' or the item type
}

/// Lists and manages archived / soft-deleted spaces and items. Transitions:
/// active → archived (archived_at), active → bin (deleted_at); restore clears
/// the relevant column; purge hard-deletes.
class StorageRepository {
  StorageRepository(this._masterKey);

  final List<int> _masterKey;

  SupabaseClient get _client => Supabase.instance.client;

  String _now() => DateTime.now().toUtc().toIso8601String();

  Future<List<StoredEntry>> loadArchived() async {
    final spaceRows = await _client
        .from('spaces')
        .select('id, name')
        .not('archived_at', 'is', null)
        .isFilter('deleted_at', null);
    final itemRows = await _client
        .from('space_items')
        .select('id, title, type')
        .not('archived_at', 'is', null)
        .isFilter('deleted_at', null);
    return _decode(spaceRows, itemRows);
  }

  Future<List<StoredEntry>> loadDeleted() async {
    final spaceRows = await _client
        .from('spaces')
        .select('id, name')
        .not('deleted_at', 'is', null);
    final itemRows = await _client
        .from('space_items')
        .select('id, title, type')
        .not('deleted_at', 'is', null);
    return _decode(spaceRows, itemRows);
  }

  Future<List<StoredEntry>> _decode(
    List<dynamic> spaces,
    List<dynamic> items,
  ) async {
    final entries = <StoredEntry>[];
    for (final r in spaces) {
      entries.add(
        StoredEntry(
          id: r['id'] as String,
          label: await ArcheCrypto.decryptArc1(
            (r['name'] ?? '') as String,
            _masterKey,
          ),
          isSpace: true,
          type: 'space',
        ),
      );
    }
    for (final r in items) {
      entries.add(
        StoredEntry(
          id: r['id'] as String,
          label: await ArcheCrypto.decryptArc1(
            (r['title'] ?? '') as String,
            _masterKey,
          ),
          isSpace: false,
          type: (r['type'] ?? '') as String,
        ),
      );
    }
    return entries;
  }

  String _table(StoredEntry e) => e.isSpace ? 'spaces' : 'space_items';

  Future<void> restoreArchived(StoredEntry e) async {
    await _client.from(_table(e)).update({'archived_at': null}).eq('id', e.id);
  }

  Future<void> restoreDeleted(StoredEntry e) async {
    await _client.from(_table(e)).update({'deleted_at': null}).eq('id', e.id);
  }

  /// Move an archived entry to the recycle bin.
  Future<void> moveToBin(StoredEntry e) async {
    await _client
        .from(_table(e))
        .update({'deleted_at': _now(), 'archived_at': null})
        .eq('id', e.id);
  }

  /// Permanently delete (hard delete). For spaces, the DB cascade removes items.
  Future<void> purge(StoredEntry e) async {
    await _client.from(_table(e)).delete().eq('id', e.id);
  }
}
