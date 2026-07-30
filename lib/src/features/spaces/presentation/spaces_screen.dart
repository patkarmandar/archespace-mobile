import 'package:flutter/material.dart';

import 'package:archespace_mobile/src/features/search/presentation/search_screen.dart';
import 'package:archespace_mobile/src/features/settings/presentation/settings_screen.dart';
import 'package:archespace_mobile/src/features/spaces/data/space_repository.dart';
import 'package:archespace_mobile/src/features/spaces/domain/space.dart';
import 'package:archespace_mobile/src/features/spaces/presentation/space_detail_screen.dart';
import 'package:archespace_mobile/src/features/spaces/presentation/space_editor_screen.dart';
import 'package:archespace_mobile/src/features/spaces/presentation/widgets/space_card.dart';
import 'package:archespace_mobile/src/features/vault/application/vault_session.dart';
import 'package:archespace_mobile/src/shared/realtime/table_watcher.dart';
import 'package:archespace_mobile/src/shared/widgets/offline_banner.dart';
import 'package:archespace_mobile/src/shared/widgets/scrollable_message.dart';

class SpacesScreen extends StatefulWidget {
  const SpacesScreen({super.key});

  @override
  State<SpacesScreen> createState() => _SpacesScreenState();
}

class _SpacesScreenState extends State<SpacesScreen> {
  List<Space>? _spaces;
  Object? _error;
  bool _offline = false;
  TableWatcher? _watcher;

  @override
  void initState() {
    super.initState();
    _load();
    _watcher = TableWatcher(
      channelName: 'spaces-realtime',
      table: 'spaces',
      onChange: _load,
    );
  }

  @override
  void dispose() {
    _watcher?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final result =
          await SpaceRepository(VaultSession.instance.masterKey).listSpaces();
      if (mounted) setState(() {
        _spaces = result.spaces;
        _offline = result.fromCache;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _createSpace() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const SpaceEditorScreen()),
    );
    if (saved == true && mounted) _load();
  }

  Future<void> _togglePinSpace(Space space) async {
    try {
      await SpaceRepository(VaultSession.instance.masterKey)
          .setPinned(space.id, !space.pinned);
      if (mounted) _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update the space.')),
        );
      }
    }
  }

  Future<void> _duplicateSpace(Space space) async {
    try {
      await SpaceRepository(VaultSession.instance.masterKey)
          .duplicateSpace(space);
      if (mounted) {
        _load();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Space duplicated')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not duplicate the space.')),
        );
      }
    }
  }

  Future<void> _archiveSpace(Space space) async {
    try {
      await SpaceRepository(VaultSession.instance.masterKey)
          .archiveSpace(space.id);
      if (mounted) {
        _load();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Space archived')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not archive the space.')),
        );
      }
    }
  }

  Future<void> _editSpace(Space space) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => SpaceEditorScreen(existing: space)),
    );
    if (saved == true && mounted) _load();
  }

  Future<void> _deleteSpace(Space space) async {
    final name = space.name.isEmpty ? 'Untitled' : space.name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Move space to bin?'),
        content: Text('"$name" and its items will be moved to the recycle bin.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Move to bin'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await SpaceRepository(VaultSession.instance.masterKey)
          .deleteSpace(space.id);
      if (mounted) _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete the space.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spaces'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SearchScreen()),
            ),
            icon: const Icon(Icons.search),
            tooltip: 'Search',
          ),
          IconButton(
            onPressed: VaultSession.instance.lock,
            icon: const Icon(Icons.lock_outline),
            tooltip: 'Lock vault',
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createSpace,
        tooltip: 'New space',
        child: const Icon(Icons.add),
      ),
      body: _spaces == null && _error == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              top: false,
              child: Column(
                children: [
                  if (_offline) const OfflineBanner(),
                  Expanded(
                    child: RefreshIndicator(onRefresh: _load, child: _body()),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _body() {
    if (_spaces == null && _error != null) {
      return ScrollableMessage('Failed to load spaces:\n$_error');
    }
    final spaces = _spaces ?? const <Space>[];
    if (spaces.isEmpty) {
      return const ScrollableMessage('No spaces yet.');
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 4, bottom: 88),
      itemCount: spaces.length,
      itemBuilder: (context, index) {
        final space = spaces[index];
        return SpaceCard(
          space: space,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SpaceDetailScreen(space: space),
            ),
          ),
          onTogglePin: () => _togglePinSpace(space),
          onEdit: () => _editSpace(space),
          onDuplicate: () => _duplicateSpace(space),
          onArchive: () => _archiveSpace(space),
          onDelete: () => _deleteSpace(space),
        );
      },
    );
  }
}
