import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import 'package:archespace_mobile/src/features/items/data/item_repository.dart';
import 'package:archespace_mobile/src/features/items/domain/item_types.dart';
import 'package:archespace_mobile/src/features/items/domain/space_item.dart';
import 'package:archespace_mobile/src/features/items/presentation/item_card.dart';
import 'package:archespace_mobile/src/features/items/presentation/item_editor_screen.dart';
import 'package:archespace_mobile/src/features/spaces/data/space_repository.dart';
import 'package:archespace_mobile/src/features/spaces/domain/space.dart';
import 'package:archespace_mobile/src/features/vault/application/vault_session.dart';
import 'package:archespace_mobile/src/shared/export/pdf_exporter.dart';
import 'package:archespace_mobile/src/shared/realtime/table_watcher.dart';
import 'package:archespace_mobile/src/shared/widgets/bulk_action_bar.dart';
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
  bool _selectMode = false;
  final Set<String> _selected = {};

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

  // ── Selection mode ──
  void _enterSelect() => setState(() => _selectMode = true);

  void _exitSelect() => setState(() {
        _selectMode = false;
        _selected.clear();
      });

  void _toggleSelect(String id) => setState(() {
        if (!_selected.remove(id)) _selected.add(id);
      });

  void _selectAll() => setState(() {
        _selected
          ..clear()
          ..addAll((_items ?? const <SpaceItem>[]).map((i) => i.id));
      });

  void _onReorder(int oldIndex, int newIndex) {
    final list = List<SpaceItem>.of(_items ?? const []);
    if (newIndex > oldIndex) newIndex -= 1;
    list.insert(newIndex, list.removeAt(oldIndex));
    setState(() => _items = list);
    _persistOrder(list);
  }

  Future<void> _persistOrder(List<SpaceItem> list) async {
    try {
      await ItemRepository(VaultSession.instance.masterKey)
          .reorder(list.map((i) => i.id).toList());
    } catch (_) {
      _showError('Could not save the new order.');
      if (mounted) _load();
    }
  }

  Future<void> _runBulk(Future<void> Function(ItemRepository) op) async {
    if (_selected.isEmpty) return;
    try {
      await op(ItemRepository(VaultSession.instance.masterKey));
      if (mounted) {
        _exitSelect();
        _load();
      }
    } catch (_) {
      _showError('Bulk action failed.');
    }
  }

  Future<void> _bulkDeleteItems() async {
    final ids = _selected.toList();
    await _runBulk((r) => r.bulkDelete(ids));
  }

  Future<void> _bulkMoveItems() async {
    List<Space> spaces;
    try {
      spaces =
          (await SpaceRepository(VaultSession.instance.masterKey).listSpaces())
              .spaces;
    } catch (_) {
      _showError('Could not load spaces.');
      return;
    }
    final destinations = spaces.where((s) => s.id != widget.space.id).toList();
    if (!mounted) return;
    if (destinations.isEmpty) {
      _showError('No other space to move to.');
      return;
    }
    final target = await showModalBottomSheet<Space>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text('Move to space',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            for (final s in destinations)
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(s.name.isEmpty ? 'Untitled' : s.name),
                onTap: () => Navigator.pop(sheetContext, s),
              ),
          ],
        ),
      ),
    );
    if (target == null) return;
    final ids = _selected.toList();
    await _runBulk((r) => r.bulkMove(ids, target.id));
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

  Future<void> _duplicateItem(SpaceItem item) async {
    try {
      await ItemRepository(VaultSession.instance.masterKey)
          .duplicateItem(widget.space.id, item);
      if (mounted) {
        _load();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item duplicated')),
        );
      }
    } catch (_) {
      _showError('Could not duplicate the item.');
    }
  }

  Future<void> _moveItem(SpaceItem item) async {
    List<Space> spaces;
    try {
      spaces =
          (await SpaceRepository(VaultSession.instance.masterKey).listSpaces())
              .spaces;
    } catch (_) {
      _showError('Could not load spaces.');
      return;
    }
    final destinations =
        spaces.where((s) => s.id != widget.space.id).toList();
    if (!mounted) return;
    if (destinations.isEmpty) {
      _showError('No other space to move to.');
      return;
    }
    final target = await showModalBottomSheet<Space>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text('Move to space',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            for (final s in destinations)
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(s.name.isEmpty ? 'Untitled' : s.name),
                onTap: () => Navigator.pop(sheetContext, s),
              ),
          ],
        ),
      ),
    );
    if (target == null) return;
    try {
      await ItemRepository(VaultSession.instance.masterKey)
          .moveItem(item.id, target.id);
      if (mounted) {
        _load();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Moved to ${target.name}')),
        );
      }
    } catch (_) {
      _showError('Could not move the item.');
    }
  }

  Future<void> _archiveItem(SpaceItem item) async {
    try {
      await ItemRepository(VaultSession.instance.masterKey).archiveItem(item.id);
      if (mounted) {
        _load();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item archived')),
        );
      }
    } catch (_) {
      _showError('Could not archive the item.');
    }
  }

  Future<void> _deleteItem(SpaceItem item) async {
    try {
      await ItemRepository(VaultSession.instance.masterKey).deleteItem(item.id);
      if (mounted) {
        _load();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item moved to recycle bin')),
        );
      }
    } catch (_) {
      _showError('Could not delete the item.');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  String _fileName(String name) {
    final safe = name.trim().replaceAll(RegExp(r'[^A-Za-z0-9._ -]'), '_');
    return '${safe.isEmpty ? 'export' : safe}.pdf';
  }

  Future<void> _exportSpace() async {
    try {
      final bytes = await PdfExporter.buildSpace(
          widget.space.name, _items ?? const []);
      await Printing.sharePdf(bytes: bytes, filename: _fileName(widget.space.name));
    } catch (_) {
      _showError('Could not export the space.');
    }
  }

  Future<void> _exportItem(SpaceItem item) async {
    try {
      final bytes = await PdfExporter.buildItem(item);
      await Printing.sharePdf(bytes: bytes, filename: _fileName(item.title));
    } catch (_) {
      _showError('Could not export the item.');
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
    final hasItems = (_items ?? const <SpaceItem>[]).isNotEmpty;
    return Scaffold(
      appBar: _selectMode
          ? AppBar(
              leading: IconButton(
                onPressed: _exitSelect,
                icon: const Icon(Icons.close),
                tooltip: 'Cancel',
              ),
              title: Text('${_selected.length} selected'),
              actions: [
                IconButton(
                  onPressed: _selectAll,
                  icon: const Icon(Icons.select_all),
                  tooltip: 'Select all',
                ),
              ],
            )
          : AppBar(
              title: Text(
                  widget.space.name.isEmpty ? 'Untitled' : widget.space.name),
              actions: [
                if (hasItems)
                  IconButton(
                    onPressed: _exportSpace,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    tooltip: 'Export PDF',
                  ),
                if (hasItems)
                  IconButton(
                    onPressed: _enterSelect,
                    icon: const Icon(Icons.checklist),
                    tooltip: 'Select',
                  ),
              ],
            ),
      floatingActionButton: _selectMode
          ? null
          : FloatingActionButton(
              onPressed: _openAddSheet,
              tooltip: 'Add item',
              child: const Icon(Icons.add),
            ),
      bottomNavigationBar: _selectMode
          ? BulkActionBar(
              count: _selected.length,
              actions: [
                BulkAction(
                  icon: Icons.push_pin,
                  label: 'Pin',
                  onPressed: () {
                    final ids = _selected.toList();
                    _runBulk((r) => r.bulkSetPinned(ids, true));
                  },
                ),
                BulkAction(
                  icon: Icons.push_pin_outlined,
                  label: 'Unpin',
                  onPressed: () {
                    final ids = _selected.toList();
                    _runBulk((r) => r.bulkSetPinned(ids, false));
                  },
                ),
                BulkAction(
                  icon: Icons.drive_file_move_outlined,
                  label: 'Move',
                  onPressed: _bulkMoveItems,
                ),
                BulkAction(
                  icon: Icons.archive_outlined,
                  label: 'Archive',
                  onPressed: () {
                    final ids = _selected.toList();
                    _runBulk((r) => r.bulkArchive(ids));
                  },
                ),
                BulkAction(
                  icon: Icons.delete_outline,
                  label: 'Delete',
                  onPressed: _bulkDeleteItems,
                ),
              ],
            )
          : null,
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
    return ReorderableListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 8, bottom: 88),
      buildDefaultDragHandles: !_selectMode && !_offline,
      onReorder: _onReorder,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isFocus = item.id == widget.focusItemId;
        return AnimatedContainer(
          key: ValueKey(item.id),
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: _flashId == item.id
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
                : Colors.transparent,
          ),
          child: KeyedSubtree(
            key: isFocus ? _focusKey : null,
            child: ItemCard(
            item: item,
            selectMode: _selectMode,
            selected: _selected.contains(item.id),
            onSelectToggle: () => _toggleSelect(item.id),
            onTap: isEditableType(item.type) ? () => _editItem(item) : null,
            onTogglePin: () => _togglePinItem(item),
            onDuplicate: () => _duplicateItem(item),
            onMove: () => _moveItem(item),
            onArchive: () => _archiveItem(item),
            onExport: () => _exportItem(item),
            onDelete: () => _deleteItem(item),
            ),
          ),
        );
      },
    );
  }
}
