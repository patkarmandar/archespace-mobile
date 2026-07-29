import 'package:flutter/material.dart';

import 'package:archespace_mobile/src/features/auth/data/auth_service.dart';
import 'package:archespace_mobile/src/features/spaces/data/space_repository.dart';
import 'package:archespace_mobile/src/features/spaces/domain/space.dart';
import 'package:archespace_mobile/src/features/spaces/presentation/space_detail_screen.dart';
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
          trailing: const Icon(Icons.chevron_right),
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
