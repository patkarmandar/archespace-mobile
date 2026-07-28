import 'package:flutter/material.dart';

import '../../core/data/item_repository.dart';
import '../../core/data/space_item.dart';
import '../../core/data/space_repository.dart';
import '../../core/vault/vault_session.dart';
import '../items/item_card.dart';

class SpaceDetailScreen extends StatefulWidget {
  const SpaceDetailScreen({super.key, required this.space});

  final Space space;

  @override
  State<SpaceDetailScreen> createState() => _SpaceDetailScreenState();
}

class _SpaceDetailScreenState extends State<SpaceDetailScreen> {
  late Future<List<SpaceItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = ItemRepository(VaultSession.instance.masterKey)
        .listItems(widget.space.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.space.name.isEmpty ? 'Untitled' : widget.space.name),
      ),
      body: FutureBuilder<List<SpaceItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Failed to load items:\n${snapshot.error}',
                    textAlign: TextAlign.center),
              ),
            );
          }
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return const Center(child: Text('No items in this space.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            itemBuilder: (context, index) => ItemCard(item: items[index]),
          );
        },
      ),
    );
  }
}
