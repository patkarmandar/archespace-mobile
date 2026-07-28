import 'package:flutter/material.dart';

import '../../core/auth/auth_service.dart';
import '../../core/data/space_repository.dart';
import '../../core/vault/vault_session.dart';
import 'space_detail_screen.dart';

class SpacesScreen extends StatefulWidget {
  const SpacesScreen({super.key});

  @override
  State<SpacesScreen> createState() => _SpacesScreenState();
}

class _SpacesScreenState extends State<SpacesScreen> {
  final AuthService _auth = AuthService();
  late Future<List<Space>> _future;

  @override
  void initState() {
    super.initState();
    _future = SpaceRepository(VaultSession.instance.masterKey).listSpaces();
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
      body: FutureBuilder<List<Space>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Failed to load spaces:\n${snapshot.error}',
                    textAlign: TextAlign.center),
              ),
            );
          }
          final spaces = snapshot.data ?? const [];
          if (spaces.isEmpty) {
            return const Center(child: Text('No spaces yet.'));
          }
          return ListView.separated(
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
        },
      ),
    );
  }
}
