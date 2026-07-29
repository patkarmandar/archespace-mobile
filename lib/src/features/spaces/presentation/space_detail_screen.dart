import 'package:flutter/material.dart';

import 'package:archespace_mobile/src/features/items/data/item_repository.dart';
import 'package:archespace_mobile/src/features/items/domain/item_types.dart';
import 'package:archespace_mobile/src/features/items/domain/space_item.dart';
import 'package:archespace_mobile/src/features/spaces/domain/space.dart';
import 'package:archespace_mobile/src/features/vault/application/vault_session.dart';
import 'package:archespace_mobile/src/features/items/presentation/item_card.dart';
import 'package:archespace_mobile/src/features/items/presentation/item_editor_screen.dart';

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
    _load();
  }

  void _load() {
    _future =
        ItemRepository(VaultSession.instance.masterKey).listItems(widget.space.id);
  }

  void _reload() => setState(_load);

  Future<void> _editItem(SpaceItem item) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ItemEditorScreen(
          spaceId: widget.space.id,
          type: item.type,
          existing: item,
        ),
      ),
    );
    if (saved == true && mounted) _reload();
  }

  Future<void> _addItem(String type) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            ItemEditorScreen(spaceId: widget.space.id, type: type),
      ),
    );
    if (saved == true && mounted) _reload();
  }

  void _openAddSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final def in kItemTypes.where((d) => d.editable))
              ListTile(
                leading: Icon(def.icon),
                title: Text(def.label),
                subtitle: Text(def.description),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _addItem(def.type);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.space.name.isEmpty ? 'Untitled' : widget.space.name),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddSheet,
        tooltip: 'Add item',
        child: const Icon(Icons.add),
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
            padding: const EdgeInsets.only(top: 8, bottom: 88),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ItemCard(
                item: item,
                onTap:
                    isEditableType(item.type) ? () => _editItem(item) : null,
              );
            },
          );
        },
      ),
    );
  }
}
