import 'package:flutter/material.dart';

import 'package:archespace_mobile/src/features/items/domain/item_types.dart';
import 'package:archespace_mobile/src/features/storage/data/storage_repository.dart';
import 'package:archespace_mobile/src/features/vault/application/vault_session.dart';

enum StorageMode { archive, bin }

/// Shared screen for the Archive and the Recycle bin. Lists archived / deleted
/// spaces and items with restore + delete actions.
class StorageScreen extends StatefulWidget {
  const StorageScreen({super.key, required this.mode});

  final StorageMode mode;

  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen> {
  final StorageRepository _repo =
      StorageRepository(VaultSession.instance.masterKey);
  List<StoredEntry>? _entries;
  Object? _error;

  bool get _isBin => widget.mode == StorageMode.bin;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final entries =
          _isBin ? await _repo.loadDeleted() : await _repo.loadArchived();
      if (mounted) {
        setState(() {
          _entries = entries;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _restore(StoredEntry e) async {
    try {
      if (_isBin) {
        await _repo.restoreDeleted(e);
      } else {
        await _repo.restoreArchived(e);
      }
      if (mounted) _load();
    } catch (_) {
      _snack('Could not restore.');
    }
  }

  Future<void> _delete(StoredEntry e) async {
    if (_isBin) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Delete permanently?'),
          content: Text('"${e.label.isEmpty ? 'Untitled' : e.label}" '
              'will be permanently deleted. This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete forever'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    try {
      if (_isBin) {
        await _repo.purge(e);
      } else {
        await _repo.moveToBin(e);
      }
      if (mounted) _load();
    } catch (_) {
      _snack('Could not delete.');
    }
  }

  void _snack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isBin ? 'Recycle bin' : 'Archive')),
      body: _entries == null && _error == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(top: false, child: _body()),
    );
  }

  Widget _body() {
    if (_entries == null && _error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Failed to load:\n$_error', textAlign: TextAlign.center),
        ),
      );
    }
    final entries = _entries ?? const <StoredEntry>[];
    if (entries.isEmpty) {
      return Center(child: Text(_isBin ? 'The bin is empty.' : 'Nothing archived.'));
    }
    final spaces = entries.where((e) => e.isSpace).toList();
    final items = entries.where((e) => !e.isSpace).toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (spaces.isNotEmpty) const _Header('Spaces'),
          for (final e in spaces) _tile(e),
          if (items.isNotEmpty) const _Header('Items'),
          for (final e in items) _tile(e),
        ],
      ),
    );
  }

  Widget _tile(StoredEntry e) {
    return ListTile(
      leading: Icon(
        e.isSpace
            ? Icons.folder_outlined
            : (itemTypeDef(e.type)?.icon ?? Icons.notes),
      ),
      title: Text(e.label.isEmpty ? 'Untitled' : e.label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => _restore(e),
            icon: const Icon(Icons.restore),
            tooltip: 'Restore',
          ),
          IconButton(
            onPressed: () => _delete(e),
            icon: Icon(_isBin ? Icons.delete_forever : Icons.delete_outline),
            tooltip: _isBin ? 'Delete permanently' : 'Move to bin',
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
