import 'package:flutter/material.dart';

import 'package:archespace_mobile/src/features/auth/data/auth_service.dart';
import 'package:archespace_mobile/src/features/spaces/data/space_repository.dart';
import 'package:archespace_mobile/src/features/spaces/domain/space.dart';
import 'package:archespace_mobile/src/features/spaces/presentation/space_detail_screen.dart';
import 'package:archespace_mobile/src/features/spaces/presentation/space_editor_screen.dart';
import 'package:archespace_mobile/src/features/vault/application/vault_session.dart';
import 'package:archespace_mobile/src/shared/realtime/table_watcher.dart';
import 'package:archespace_mobile/src/shared/widgets/scrollable_message.dart';

class SpacesScreen extends StatefulWidget {
  const SpacesScreen({super.key});

  @override
  State<SpacesScreen> createState() => _SpacesScreenState();
}

class _SpacesScreenState extends State<SpacesScreen> {
  final AuthService _auth = AuthService();
  List<Space>? _spaces;
  Object? _error;
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
      final spaces =
          await SpaceRepository(VaultSession.instance.masterKey).listSpaces();
      if (mounted) setState(() {
        _spaces = spaces;
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
            onPressed: VaultSession.instance.lock,
            icon: const Icon(Icons.lock_outline),
            tooltip: 'Lock vault',
          ),
          IconButton(
            onPressed: _auth.signOut,
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
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
          : RefreshIndicator(onRefresh: _load, child: _body()),
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
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: spaces.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final space = spaces[index];
        return ListTile(
          leading: Icon(
            space.pinned ? Icons.push_pin : Icons.folder_outlined,
          ),
          title: Text(space.name.isEmpty ? 'Untitled' : space.name),
          subtitle: space.description.isEmpty
              ? null
              : Text(
                  space.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') _editSpace(space);
              if (value == 'delete') _deleteSpace(space);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SpaceDetailScreen(space: space),
            ),
          ),
        );
      },
    );
  }
}
