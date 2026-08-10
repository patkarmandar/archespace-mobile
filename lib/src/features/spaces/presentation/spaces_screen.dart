import 'package:flutter/material.dart';

import 'package:archespace_mobile/src/features/search/presentation/search_screen.dart';
import 'package:archespace_mobile/src/features/settings/presentation/settings_screen.dart';
import 'package:archespace_mobile/src/features/spaces/data/space_repository.dart';
import 'package:archespace_mobile/src/features/spaces/domain/space.dart';
import 'package:archespace_mobile/src/features/spaces/presentation/space_detail_screen.dart';
import 'package:archespace_mobile/src/features/spaces/presentation/space_editor_screen.dart';
import 'package:archespace_mobile/src/features/spaces/presentation/widgets/space_card.dart';
import 'package:archespace_mobile/src/features/vault/application/vault_session.dart';
import 'package:archespace_mobile/src/shared/offline/write_queue.dart';
import 'package:archespace_mobile/src/shared/realtime/table_watcher.dart';
import 'package:archespace_mobile/src/shared/sort/sort.dart';
import 'package:archespace_mobile/src/shared/widgets/bulk_action_bar.dart';
import 'package:archespace_mobile/src/shared/widgets/offline_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool _selectMode = false;
  final Set<String> _selected = {};
  String _sort = kSortDefault;

  @override
  void initState() {
    super.initState();
    _load();
    SharedPreferences.getInstance().then((prefs) {
      final saved = prefs.getString('sort_spaces');
      if (saved != null && mounted) setState(() => _sort = saved);
    });
    _watcher = TableWatcher(
      channelName: 'spaces-realtime',
      table: 'spaces',
      onChange: _load,
    );
  }

  void _setSort(String value) {
    setState(() => _sort = value);
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setString('sort_spaces', value),
    );
  }

  @override
  void dispose() {
    _watcher?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final result = await SpaceRepository(
        VaultSession.instance.masterKey,
      ).listSpaces();
      if (mounted) {
        setState(() {
          _spaces = result.spaces;
          _offline = result.fromCache;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _createSpace() async {
    final saved = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const SpaceEditorScreen()));
    if (saved == true && mounted) _load();
  }

  Future<void> _togglePinSpace(Space space) async {
    try {
      await SpaceRepository(
        VaultSession.instance.masterKey,
      ).setPinned(space.id, !space.pinned);
      if (mounted) _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't update the space.")),
        );
      }
    }
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
      ..addAll((_spaces ?? const <Space>[]).map((s) => s.id));
  });

  void _snack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// `newIndex` arrives already adjusted for the removed item (onReorderItem).
  void _onReorder(int oldIndex, int newIndex) {
    final list = List<Space>.of(_spaces ?? const []);
    list.insert(newIndex, list.removeAt(oldIndex));
    setState(() => _spaces = list);
    _persistOrder(list);
  }

  Future<void> _persistOrder(List<Space> list) async {
    try {
      await SpaceRepository(
        VaultSession.instance.masterKey,
      ).reorder(list.map((s) => s.id).toList());
    } catch (_) {
      _snack("Couldn't save the new order.");
      if (mounted) _load();
    }
  }

  Future<void> _runBulk(Future<void> Function(SpaceRepository) op) async {
    final ids = _selected.toList();
    if (ids.isEmpty) return;
    try {
      await op(SpaceRepository(VaultSession.instance.masterKey));
      if (mounted) {
        _exitSelect();
        _load();
      }
    } catch (_) {
      _snack("Couldn't complete that action.");
    }
  }

  Future<void> _bulkDelete() async {
    final count = _selected.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Move $count ${count == 1 ? 'space' : 'spaces'} to bin?'),
        content: const Text('They and their items go to the recycle bin.'),
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
    final ids = _selected.toList();
    await _runBulk((r) => r.bulkDelete(ids));
  }

  Future<void> _duplicateSpace(Space space) async {
    try {
      await SpaceRepository(
        VaultSession.instance.masterKey,
      ).duplicateSpace(space);
      if (mounted) {
        _load();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Space duplicated')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't duplicate the space.")),
        );
      }
    }
  }

  Future<void> _archiveSpace(Space space) async {
    try {
      await SpaceRepository(
        VaultSession.instance.masterKey,
      ).archiveSpace(space.id);
      if (mounted) {
        _load();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Space archived')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't archive the space.")),
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
        content: Text(
          '"$name" and its items will be moved to the recycle bin.',
        ),
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
      await SpaceRepository(
        VaultSession.instance.masterKey,
      ).deleteSpace(space.id);
      if (mounted) _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't delete the space.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSpaces = (_spaces ?? const <Space>[]).isNotEmpty;
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
              title: const Text('Arche Space'),
              actions: [
                IconButton(
                  onPressed: VaultSession.instance.lock,
                  icon: const Icon(Icons.lock_outline),
                  tooltip: 'Lock vault',
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Settings',
                ),
              ],
            ),
      floatingActionButton: _selectMode
          ? null
          : FloatingActionButton(
              onPressed: _createSpace,
              tooltip: 'New space',
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
                  onPressed: _bulkDelete,
                ),
              ],
            )
          : null,
      body: _spaces == null && _error == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              top: false,
              child: Column(
                children: [
                  if (!_selectMode && hasSpaces) _buildSearchBar(context),
                  if (!_selectMode && hasSpaces)
                    _buildSpacesHeader(
                      context,
                      (_spaces ?? const <Space>[]).length,
                    ),
                  if (_offline) const OfflineBanner(),
                  ValueListenableBuilder<int>(
                    valueListenable: WriteQueue.instance.pending,
                    builder: (context, count, _) => count == 0
                        ? const SizedBox.shrink()
                        : Container(
                            width: double.infinity,
                            color: Theme.of(
                              context,
                            ).colorScheme.tertiaryContainer,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Text(
                              '$count change${count == 1 ? '' : 's'} waiting to sync',
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onTertiaryContainer,
                              ),
                            ),
                          ),
                  ),
                  Expanded(
                    child: RefreshIndicator(onRefresh: _load, child: _body()),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const SearchScreen())),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.search, size: 20, color: scheme.onSurfaceVariant),
                const SizedBox(width: 10),
                Text(
                  'Search spaces and items',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpacesHeader(BuildContext context, int count) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 4, top: 4, bottom: 4),
      child: Row(
        children: [
          Text(
            'Spaces',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '· $count',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: _enterSelect,
            icon: const Icon(Icons.checklist),
            tooltip: 'Select',
          ),
          SortMenu(value: _sort, onChanged: _setSort),
        ],
      ),
    );
  }

  Widget _body() {
    if (_spaces == null && _error != null) {
      return ScrollableMessage('Failed to load spaces:\n$_error');
    }
    final all = _spaces ?? const <Space>[];
    if (all.isEmpty) {
      return const ScrollableMessage(
        'No spaces yet.\nTap + to create your first space.',
      );
    }
    final spaces = applySort(
      all,
      _sort,
      name: (s) => s.name,
      createdAt: (s) => s.createdAt,
      pinned: (s) => s.pinned,
    );
    return ReorderableListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 4, bottom: 88),
      buildDefaultDragHandles:
          !_selectMode && !_offline && _sort == kSortDefault,
      onReorderItem: _onReorder,
      itemCount: spaces.length,
      itemBuilder: (context, index) {
        final space = spaces[index];
        return SpaceCard(
          key: ValueKey(space.id),
          space: space,
          selectMode: _selectMode,
          selected: _selected.contains(space.id),
          onSelectToggle: () => _toggleSelect(space.id),
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
