import 'package:flutter/material.dart';

import 'package:archespace_mobile/src/features/items/data/item_repository.dart';
import 'package:archespace_mobile/src/features/items/domain/item_types.dart';
import 'package:archespace_mobile/src/features/items/domain/space_item.dart';
import 'package:archespace_mobile/src/features/items/presentation/item_card.dart';
import 'package:archespace_mobile/src/features/items/presentation/item_editor_screen.dart';
import 'package:archespace_mobile/src/features/spaces/domain/space.dart';
import 'package:archespace_mobile/src/features/vault/application/vault_session.dart';
import 'package:archespace_mobile/src/shared/realtime/table_watcher.dart';
import 'package:archespace_mobile/src/shared/widgets/offline_banner.dart';
import 'package:archespace_mobile/src/shared/widgets/scrollable_message.dart';

class SpaceDetailScreen extends StatefulWidget {
  const SpaceDetailScreen({super.key, required this.space, this.focusItemId});

  final Space space;

  /// When set, the screen scrolls to this item and briefly highlights it
  /// (used by search's jump-to-item).
  final String? focusItemId;

  @override
  State<SpaceDetailScreen> createState() => _SpaceDetailScreenState();
}

class _SpaceDetailScreenState extends State<SpaceDetailScreen> {
  List<SpaceItem>? _items;
  Object? _error;
  bool _offline = false;
  TableWatcher? _watcher;
  final GlobalKey _focusKey = GlobalKey();
  String? _flashId;
  bool _focusHandled = false;

  @override
  void initState() {
    super.initState();
    _load();
    _watcher = TableWatcher(
      channelName: 'items-${widget.space.id}',
      table: 'space_items',
      filterColumn: 'space_id',
      filterValue: widget.space.id,
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
      final result = await ItemRepository(VaultSession.instance.masterKey)
          .listItems(widget.space.id);
      if (mounted) setState(() {
        _items = result.items;
        _offline = result.fromCache;
        _error = null;
      });
      if (widget.focusItemId != null && !_focusHandled && mounted) {
        _focusHandled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _revealFocus());
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _revealFocus() {
    final ctx = _focusKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        alignment: 0.1,
      );
    }
    setState(() => _flashId = widget.focusItemId);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _flashId = null);
    });
  }

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
    if (saved == true && mounted) _load();
  }

  Future<void> _togglePinItem(SpaceItem item) async {
    try {
      await ItemRepository(VaultSession.instance.masterKey)
          .setPinned(item.id, !item.pinned);
      if (mounted) _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update the item.')),
        );
      }
    }
  }

  Future<void> _addItem(String type) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ItemEditorScreen(spaceId: widget.space.id, type: type),
      ),
    );
    if (saved == true && mounted) _load();
  }

  void _openAddSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 8),
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
      body: _items == null && _error == null
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
    if (_items == null && _error != null) {
      return ScrollableMessage('Failed to load items:\n$_error');
    }
    final items = _items ?? const <SpaceItem>[];
    if (items.isEmpty) {
      return const ScrollableMessage('No items in this space.');
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 8, bottom: 88),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isFocus = item.id == widget.focusItemId;
        return AnimatedContainer(
          key: isFocus ? _focusKey : null,
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: _flashId == item.id
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
                : Colors.transparent,
          ),
          child: ItemCard(
            item: item,
            onTap: isEditableType(item.type) ? () => _editItem(item) : null,
            onTogglePin: () => _togglePinItem(item),
          ),
        );
      },
    );
  }
}
