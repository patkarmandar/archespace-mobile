import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:archespace_mobile/src/features/auth/data/auth_service.dart';
import 'package:archespace_mobile/src/features/items/data/item_repository.dart';
import 'package:archespace_mobile/src/features/items/domain/item_types.dart';
import 'package:archespace_mobile/src/features/items/domain/space_item.dart';
import 'package:archespace_mobile/src/features/vault/application/vault_session.dart';
import 'package:archespace_mobile/src/features/vault/data/vault_service.dart';
import 'package:archespace_mobile/src/shared/crypto/arche_crypto.dart';
import 'package:archespace_mobile/src/shared/util/errors.dart';

/// Full-screen editor for one item. Pass [existing] to edit, or [type] (with no
/// [existing]) to create. The per-type body editor mutates [_content] in place;
/// Save re-encrypts and writes to Supabase, then pops `true` so the caller can
/// refresh.
class ItemEditorScreen extends StatefulWidget {
  const ItemEditorScreen({
    super.key,
    required this.spaceId,
    required this.type,
    this.existing,
  });

  final String spaceId;
  final String type;
  final SpaceItem? existing;

  @override
  State<ItemEditorScreen> createState() => _ItemEditorScreenState();
}

class _ItemEditorScreenState extends State<ItemEditorScreen> {
  late final TextEditingController _title = TextEditingController(
    text: widget.existing?.title ?? '',
  );
  late final Map<String, dynamic> _content = _initialContent();

  // Null until the item exists in the backend. Set after the first save of a
  // new item so later auto-saves update it instead of creating duplicates.
  late String? _itemId = widget.existing?.id;

  bool _saving = false;

  // Snapshot of the last persisted state, for change detection.
  late String _savedTitle = (widget.existing?.title ?? '').trim();
  late String _savedContentJson = jsonEncode(_content);
  // True once any save has succeeded, so the caller refreshes on close.
  bool _savedAny = false;

  // The Secret editor keeps its plaintext to itself (folded into `_content`
  // only at save via finalize), so its edits can't be seen by diffing
  // `_content`. It signals changes through these flags instead.
  bool _secretDirty = false;
  bool _secretChangedSinceTick = false;

  // Previous auto-save tick's snapshot, so we only save once edits settle
  // (no change since the last tick) rather than on every keystroke.
  late String _tickTitle = _title.text;
  late String _tickContentJson = _savedContentJson;
  Timer? _autoSaveTimer;

  // Some editors (Secret) must run async work (encryption) to fold their state
  // into `_content` just before saving. They register that step here.
  Future<void> Function()? _finalizeContent;

  Map<String, dynamic> _initialContent() {
    final source = widget.existing?.content ?? defaultContentFor(widget.type);
    // Deep copy so editing never mutates the item still shown in the list.
    return jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
  }

  @override
  void initState() {
    super.initState();
    _autoSaveTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _autoTick(),
    );
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _title.dispose();
    super.dispose();
  }

  bool _isDirty() =>
      _title.text.trim() != _savedTitle ||
      jsonEncode(_content) != _savedContentJson ||
      _secretDirty;

  // Auto-save unsaved edits once they settle (unchanged since the last tick),
  // so we don't write on every keystroke.
  void _autoTick() {
    if (_saving) return;
    final curTitle = _title.text;
    final curJson = jsonEncode(_content);
    final dirty =
        curTitle.trim() != _savedTitle ||
        curJson != _savedContentJson ||
        _secretDirty;
    final settled =
        curTitle == _tickTitle &&
        curJson == _tickContentJson &&
        !_secretChangedSinceTick;
    _tickTitle = curTitle;
    _tickContentJson = curJson;
    _secretChangedSinceTick = false;
    if (dirty && settled) _save(silent: true);
  }

  /// Persists the item. Returns true on success. [silent] suppresses the error
  /// snackbar (used by background auto-save). Never navigates.
  Future<bool> _save({bool silent = false}) async {
    if (_saving) return false;
    setState(() => _saving = true);
    final repo = ItemRepository(VaultSession.instance.masterKey);
    try {
      if (_finalizeContent != null) await _finalizeContent!();
      final title = _title.text.trim();
      if (_itemId != null) {
        await repo.updateItem(
          id: _itemId!,
          spaceId: widget.spaceId,
          type: widget.type,
          title: title,
          content: _content,
        );
      } else {
        _itemId = await repo.createItem(
          spaceId: widget.spaceId,
          type: widget.type,
          title: title,
          content: _content,
        );
      }
      _savedTitle = title;
      _savedContentJson = jsonEncode(_content);
      _secretDirty = false;
      _savedAny = true;
      if (mounted) setState(() => _saving = false);
      return true;
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        if (!silent) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(saveErrorMessage(e))));
        }
      }
      return false;
    }
  }

  Future<void> _saveAndClose() async {
    if (await _save() && mounted) Navigator.pop(context, true);
  }

  // Flush on leave: save pending edits, then close. On a save failure the user
  // stays in the editor (with the error) so nothing is lost.
  Future<void> _handleBack() async {
    if (!_isDirty()) {
      if (mounted) Navigator.pop(context, _savedAny);
      return;
    }
    if (await _save() && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final label = itemTypeDef(widget.type)?.label ?? 'Item';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.existing != null ? 'Edit $label' : 'New $label'),
          actions: [
            _saving
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    onPressed: _saveAndClose,
                    icon: const Icon(Icons.check),
                    tooltip: 'Save',
                  ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _title,
                  style: Theme.of(context).textTheme.titleLarge,
                  decoration: const InputDecoration(
                    hintText: 'Title',
                    border: InputBorder.none,
                  ),
                ),
                const Divider(),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (widget.type) {
      case 'textbox':
      case 'markdown':
        return _NoteEditor(content: _content);
      case 'menu_list':
        return _ListEditor(content: _content, variant: _ListVariant.bullet);
      case 'numbered_list':
        return _ListEditor(content: _content, variant: _ListVariant.numbered);
      case 'checkbox_list':
        return _ListEditor(content: _content, variant: _ListVariant.checklist);
      case 'card_list':
        return _CardsEditor(content: _content);
      case 'table':
        return _TableEditor(content: _content);
      case 'draw':
        return _DrawEditor(content: _content);
      case 'secret':
        return _SecretEditor(
          content: _content,
          onRegisterFinalize: (fn) => _finalizeContent = fn,
          onChanged: () {
            _secretDirty = true;
            _secretChangedSinceTick = true;
          },
        );
      default:
        return Center(child: Text("You can't edit this item type yet."));
    }
  }
}

/// Plain multiline text editor for note / markdown content (`{ text }`).
class _NoteEditor extends StatefulWidget {
  const _NoteEditor({required this.content});

  final Map<String, dynamic> content;

  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  late final TextEditingController _text = TextEditingController(
    text: (widget.content['text'] ?? '').toString(),
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _text,
      onChanged: (value) => widget.content['text'] = value,
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      keyboardType: TextInputType.multiline,
      decoration: const InputDecoration(
        hintText: 'Start writing…',
        border: InputBorder.none,
      ),
    );
  }
}

enum _ListVariant { bullet, numbered, checklist }

/// Editable rows for `menu_list` / `numbered_list` / `checkbox_list`
/// (`{ items: [{id, text, checked?}] }`). Add, edit, remove, and drag to
/// reorder. [variant] controls the leading marker (bullet / number / checkbox).
class _ListEditor extends StatefulWidget {
  const _ListEditor({required this.content, required this.variant});

  final Map<String, dynamic> content;
  final _ListVariant variant;

  @override
  State<_ListEditor> createState() => _ListEditorState();
}

class _ListEditorState extends State<_ListEditor> {
  late final List<Map<String, dynamic>> _items;
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _items = (((widget.content['items'] as List?) ?? const []))
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    for (final item in _items) {
      item['id'] ??= _uid();
    }
    // Share the same list instance so edits flow into the saved content.
    widget.content['items'] = _items;
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(Map<String, dynamic> item) {
    return _controllers.putIfAbsent(
      item['id'] as String,
      () => TextEditingController(text: (item['text'] ?? '').toString()),
    );
  }

  void _add() {
    setState(
      () => _items.add({
        'id': _uid(),
        'text': '',
        if (widget.variant == _ListVariant.checklist) 'checked': false,
      }),
    );
  }

  Widget _leading(int index, Map<String, dynamic> item) {
    switch (widget.variant) {
      case _ListVariant.numbered:
        return SizedBox(
          width: 28,
          child: Text('${index + 1}.', textAlign: TextAlign.center),
        );
      case _ListVariant.bullet:
        return const SizedBox(
          width: 28,
          child: Text('•', textAlign: TextAlign.center),
        );
      case _ListVariant.checklist:
        return Checkbox(
          value: (item['checked'] ?? false) == true,
          onChanged: (value) =>
              setState(() => item['checked'] = value ?? false),
        );
    }
  }

  void _remove(int index) {
    final id = _items[index]['id'] as String;
    setState(() => _items.removeAt(index));
    _controllers.remove(id)?.dispose();
  }

  /// `newIndex` arrives already adjusted for the removed item (onReorderItem).
  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ReorderableListView.builder(
            itemCount: _items.length,
            onReorderItem: _reorder,
            itemBuilder: (context, index) {
              final item = _items[index];
              return Padding(
                key: ValueKey(item['id']),
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    _leading(index, item),
                    Expanded(
                      child: TextField(
                        controller: _controllerFor(item),
                        onChanged: (value) => item['text'] = value,
                        minLines: 1,
                        maxLines: null,
                        style:
                            widget.variant == _ListVariant.checklist &&
                                (item['checked'] ?? false) == true
                            ? const TextStyle(
                                decoration: TextDecoration.lineThrough,
                              )
                            : null,
                        decoration: const InputDecoration(
                          hintText: 'Item…',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _remove(index),
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Remove',
                    ),
                    ReorderableDragStartListener(
                      index: index,
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          Icons.drag_handle,
                          size: 18,
                          semanticLabel: 'Drag to reorder',
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.add),
            label: const Text('Add item'),
          ),
        ),
      ],
    );
  }
}

int _idCounter = 0;
String _uid() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${(_idCounter++).toRadixString(36)}';

/// Editable cards for `card_list` (`{ items: [{id, title, description}] }`).
/// Two fields per card; add, remove, and drag to reorder.
class _CardsEditor extends StatefulWidget {
  const _CardsEditor({required this.content});

  final Map<String, dynamic> content;

  @override
  State<_CardsEditor> createState() => _CardsEditorState();
}

class _CardsEditorState extends State<_CardsEditor> {
  late final List<Map<String, dynamic>> _items;
  final Map<String, TextEditingController> _titleCtrls = {};
  final Map<String, TextEditingController> _descCtrls = {};

  @override
  void initState() {
    super.initState();
    _items = (((widget.content['items'] as List?) ?? const []))
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    for (final item in _items) {
      item['id'] ??= _uid();
    }
    widget.content['items'] = _items;
  }

  @override
  void dispose() {
    for (final controller in _titleCtrls.values) {
      controller.dispose();
    }
    for (final controller in _descCtrls.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _titleFor(Map<String, dynamic> item) =>
      _titleCtrls.putIfAbsent(
        item['id'] as String,
        () => TextEditingController(text: (item['title'] ?? '').toString()),
      );

  TextEditingController _descFor(Map<String, dynamic> item) =>
      _descCtrls.putIfAbsent(
        item['id'] as String,
        () =>
            TextEditingController(text: (item['description'] ?? '').toString()),
      );

  void _add() {
    setState(() => _items.add({'id': _uid(), 'title': '', 'description': ''}));
  }

  void _remove(int index) {
    final id = _items[index]['id'] as String;
    setState(() => _items.removeAt(index));
    _titleCtrls.remove(id)?.dispose();
    _descCtrls.remove(id)?.dispose();
  }

  /// `newIndex` arrives already adjusted for the removed item (onReorderItem).
  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ReorderableListView.builder(
            itemCount: _items.length,
            onReorderItem: _reorder,
            itemBuilder: (context, index) {
              final item = _items[index];
              return Padding(
                key: ValueKey(item['id']),
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 4, 4, 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _titleFor(item),
                              onChanged: (value) => item['title'] = value,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Title',
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _remove(index),
                            icon: const Icon(Icons.close, size: 18),
                            tooltip: 'Remove',
                          ),
                          ReorderableDragStartListener(
                            index: index,
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(
                                Icons.drag_handle,
                                size: 18,
                                semanticLabel: 'Drag to reorder',
                              ),
                            ),
                          ),
                        ],
                      ),
                      TextField(
                        controller: _descFor(item),
                        onChanged: (value) => item['description'] = value,
                        minLines: 1,
                        maxLines: null,
                        decoration: const InputDecoration(
                          hintText: 'Description',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.add),
            label: const Text('Add card'),
          ),
        ),
      ],
    );
  }
}

const double _kCellWidth = 150;

/// Grid editor for `table` (`{ columns: [labels], rows: [[cells]] }`). Edit the
/// header + cells, add/remove columns and rows. The grid is kept rectangular
/// (every row has one cell per column). Scrolls both axes.
class _TableEditor extends StatefulWidget {
  const _TableEditor({required this.content});

  final Map<String, dynamic> content;

  @override
  State<_TableEditor> createState() => _TableEditorState();
}

class _TableEditorState extends State<_TableEditor> {
  late final List<String> _columns;
  late final List<List<String>> _rows;
  late final List<TextEditingController> _colCtrls;
  late final List<List<TextEditingController>> _cellCtrls;

  @override
  void initState() {
    super.initState();
    _columns = (((widget.content['columns'] as List?) ?? const []))
        .map((e) => (e ?? '').toString())
        .toList();
    if (_columns.isEmpty) {
      _columns.addAll(['', '']);
    }
    _rows = (((widget.content['rows'] as List?) ?? const []))
        .map(
          (r) => (((r as List?) ?? const []))
              .map((e) => (e ?? '').toString())
              .toList(),
        )
        .toList();
    // Keep every row the width of the header.
    for (final row in _rows) {
      while (row.length < _columns.length) {
        row.add('');
      }
      if (row.length > _columns.length) {
        row.removeRange(_columns.length, row.length);
      }
    }
    if (_rows.isEmpty) {
      _rows.add(List<String>.filled(_columns.length, '', growable: true));
    }

    _colCtrls = [for (final c in _columns) TextEditingController(text: c)];
    _cellCtrls = [
      for (final row in _rows)
        [for (final cell in row) TextEditingController(text: cell)],
    ];

    // Share the same list instances so edits flow into the saved content.
    widget.content['columns'] = _columns;
    widget.content['rows'] = _rows;
  }

  @override
  void dispose() {
    for (final controller in _colCtrls) {
      controller.dispose();
    }
    for (final row in _cellCtrls) {
      for (final controller in row) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  void _addColumn() {
    setState(() {
      _columns.add('');
      _colCtrls.add(TextEditingController());
      for (var r = 0; r < _rows.length; r++) {
        _rows[r].add('');
        _cellCtrls[r].add(TextEditingController());
      }
    });
  }

  void _removeColumn(int c) {
    if (_columns.length <= 1) return;
    setState(() {
      _columns.removeAt(c);
      _colCtrls.removeAt(c).dispose();
      for (var r = 0; r < _rows.length; r++) {
        _rows[r].removeAt(c);
        _cellCtrls[r].removeAt(c).dispose();
      }
    });
  }

  void _addRow() {
    setState(() {
      _rows.add(List<String>.filled(_columns.length, '', growable: true));
      _cellCtrls.add([
        for (var c = 0; c < _columns.length; c++) TextEditingController(),
      ]);
    });
  }

  void _removeRow(int r) {
    if (_rows.length <= 1) return;
    setState(() {
      _rows.removeAt(r);
      for (final controller in _cellCtrls.removeAt(r)) {
        controller.dispose();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final border = Border.all(color: Theme.of(context).dividerColor);
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row + add-column button.
                  Row(
                    children: [
                      for (var c = 0; c < _columns.length; c++)
                        Container(
                          width: _kCellWidth,
                          decoration: BoxDecoration(
                            border: border,
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                          ),
                          padding: const EdgeInsets.only(left: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _colCtrls[c],
                                  onChanged: (v) => _columns[c] = v,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Column ${c + 1}',
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                ),
                              ),
                              if (_columns.length > 1)
                                InkWell(
                                  onTap: () => _removeColumn(c),
                                  child: const Padding(
                                    padding: EdgeInsets.all(6),
                                    child: Icon(Icons.close, size: 14),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      IconButton(
                        onPressed: _addColumn,
                        icon: const Icon(Icons.add),
                        tooltip: 'Add column',
                      ),
                    ],
                  ),
                  // Data rows + remove-row button.
                  for (var r = 0; r < _rows.length; r++)
                    Row(
                      children: [
                        for (var c = 0; c < _columns.length; c++)
                          Container(
                            width: _kCellWidth,
                            decoration: BoxDecoration(border: border),
                            child: TextField(
                              controller: _cellCtrls[r][c],
                              onChanged: (v) => _rows[r][c] = v,
                              minLines: 1,
                              maxLines: null,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                        IconButton(
                          onPressed: _rows.length > 1
                              ? () => _removeRow(r)
                              : null,
                          icon: const Icon(Icons.close, size: 16),
                          tooltip: 'Remove row',
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addRow,
            icon: const Icon(Icons.add),
            label: const Text('Add row'),
          ),
        ),
      ],
    );
  }
}

const List<String> _kInkColors = [
  '#1e293b',
  '#e11d48',
  '#2563eb',
  '#059669',
  '#d97706',
  '#7c3aed',
];
const List<double> _kInkSizes = [4, 8, 16];

/// Freehand canvas for `draw`
/// (`{ strokes: [{ points: [[x, y, pressure], …], color, size }] }`).
/// Points are captured in a fixed 1000x600 logical space so drawings scale and
/// match the read renderer / web. Includes colour + size pickers, undo, clear.
class _DrawEditor extends StatefulWidget {
  const _DrawEditor({required this.content});

  final Map<String, dynamic> content;

  @override
  State<_DrawEditor> createState() => _DrawEditorState();
}

class _DrawEditorState extends State<_DrawEditor> {
  late final List<dynamic> _strokes;
  Map<String, dynamic>? _current;
  String _color = _kInkColors.first;
  double _size = _kInkSizes[1];
  Size _canvas = Size.zero;

  @override
  void initState() {
    super.initState();
    _strokes = List<dynamic>.from(
      (widget.content['strokes'] as List?) ?? const [],
    );
    widget.content['strokes'] = _strokes;
  }

  List<double> _toLogical(Offset local, double pressure) {
    final w = _canvas.width <= 0 ? 1.0 : _canvas.width;
    final h = _canvas.height <= 0 ? 1.0 : _canvas.height;
    return [local.dx / w * 1000, local.dy / h * 600, pressure];
  }

  void _start(Offset p, double pressure) {
    setState(
      () => _current = {
        'points': [_toLogical(p, pressure)],
        'color': _color,
        'size': _size,
      },
    );
  }

  void _extend(Offset p, double pressure) {
    if (_current == null) return;
    setState(() => (_current!['points'] as List).add(_toLogical(p, pressure)));
  }

  void _end() {
    final current = _current;
    if (current != null && (current['points'] as List).isNotEmpty) {
      _strokes.add(current);
    }
    setState(() => _current = null);
  }

  void _undo() {
    if (_strokes.isEmpty) return;
    setState(_strokes.removeLast);
  }

  void _clear() {
    setState(_strokes.clear);
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final col in _kInkColors)
              GestureDetector(
                onTap: () => setState(() => _color = col),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _parseInk(col, Colors.black),
                    border: Border.all(
                      color: _color == col ? accent : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 8),
            for (final s in _kInkSizes)
              GestureDetector(
                onTap: () => setState(() => _size = s),
                child: Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _size == s
                          ? accent
                          : Theme.of(context).dividerColor,
                    ),
                  ),
                  child: Container(
                    width: s,
                    height: s,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            const Spacer(),
            IconButton(
              onPressed: _strokes.isEmpty ? null : _undo,
              icon: const Icon(Icons.undo),
              tooltip: 'Undo',
            ),
            IconButton(
              onPressed: _strokes.isEmpty ? null : _clear,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear',
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1000 / 600,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _canvas = Size(constraints.maxWidth, constraints.maxHeight);
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Theme.of(context).dividerColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (e) =>
                            _start(e.localPosition, e.pressure),
                        onPointerMove: (e) =>
                            _extend(e.localPosition, e.pressure),
                        onPointerUp: (e) => _end(),
                        child: CustomPaint(
                          painter: _DrawPainter(_strokes, _current),
                          // A concrete expanding child guarantees the canvas fills
                          // the box and stays hit-testable; `size: Size.infinite`
                          // with no child can collapse to zero under loose
                          // constraints, leaving nothing to draw on.
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DrawPainter extends CustomPainter {
  _DrawPainter(this.strokes, this.current);

  final List<dynamic> strokes;
  final Map<String, dynamic>? current;

  void _paintStroke(Canvas canvas, Size size, Map<dynamic, dynamic> stroke) {
    final points = (stroke['points'] as List?) ?? const [];
    if (points.isEmpty) return;
    final paint = Paint()
      ..color = _parseInk(stroke['color'], const Color(0xFF1E293B))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth =
          ((stroke['size'] as num?)?.toDouble() ?? 8) * size.width / 1000;

    final offsets = <Offset>[];
    for (final p in points) {
      if (p is! List || p.length < 2) continue;
      final x = (p[0] as num).toDouble() / 1000 * size.width;
      final y = (p[1] as num).toDouble() / 600 * size.height;
      offsets.add(Offset(x, y));
    }
    if (offsets.isEmpty) return;

    // A single point (a tap) has no line to stroke, so render it as a dot.
    if (offsets.length == 1) {
      canvas.drawCircle(
        offsets.first,
        paint.strokeWidth / 2,
        Paint()..color = paint.color,
      );
      return;
    }

    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (final o in offsets.skip(1)) {
      path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      if (s is Map) _paintStroke(canvas, size, s);
    }
    final current = this.current;
    if (current != null) _paintStroke(canvas, size, current);
  }

  @override
  bool shouldRepaint(covariant _DrawPainter oldDelegate) => true;
}

Color _parseInk(Object? hex, Color fallback) {
  if (hex is String && hex.startsWith('#') && hex.length == 7) {
    final value = int.tryParse(hex.substring(1), radix: 16);
    if (value != null) return Color(0xFF000000 | value);
  }
  return fallback;
}

/// Editor for `secret` (`{ secret: true, cipher: <arc1> }`). The secret text is
/// a nested cipher; revealing/editing it requires re-verifying the vault PIN.
/// A new/empty secret is editable directly; an existing one starts locked.
/// On save, the plaintext is re-encrypted with the master key into `cipher`.
class _SecretEditor extends StatefulWidget {
  const _SecretEditor({
    required this.content,
    required this.onRegisterFinalize,
    required this.onChanged,
  });

  final Map<String, dynamic> content;
  final void Function(Future<void> Function()) onRegisterFinalize;
  final VoidCallback onChanged;

  @override
  State<_SecretEditor> createState() => _SecretEditorState();
}

class _SecretEditorState extends State<_SecretEditor> {
  final AuthService _auth = AuthService();
  final VaultService _vault = VaultService();
  final TextEditingController _text = TextEditingController();
  final TextEditingController _pin = TextEditingController();

  bool _revealed = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final cipher = (widget.content['cipher'] ?? '').toString();
    // A new / empty secret is editable straight away; existing ciphers stay
    // locked until the PIN is re-verified.
    _revealed = cipher.isEmpty;
    widget.onRegisterFinalize(_finalize);
  }

  @override
  void dispose() {
    _text.dispose();
    _pin.dispose();
    super.dispose();
  }

  // Fold the plaintext back into the (nested) cipher before saving. If never
  // revealed, the existing cipher is left untouched (only the title changed).
  Future<void> _finalize() async {
    if (!_revealed) return;
    widget.content['secret'] = true;
    widget.content['cipher'] = await ArcheCrypto.encryptArc1(
      _text.text,
      VaultSession.instance.masterKey,
    );
  }

  Future<void> _reveal() async {
    final userId = _auth.currentUser?.id;
    if (userId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Re-verify the vault PIN (throws on a wrong PIN).
      await _vault.unlock(userId, _pin.text.trim());
      final cipher = (widget.content['cipher'] ?? '').toString();
      _text.text = cipher.isEmpty
          ? ''
          : await ArcheCrypto.decryptArc1(
              cipher,
              VaultSession.instance.masterKey,
            );
      setState(() => _revealed = true);
    } on VaultException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = "Couldn't verify your PIN.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_revealed) {
      return TextField(
        controller: _text,
        onChanged: (_) => widget.onChanged(),
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        keyboardType: TextInputType.multiline,
        decoration: const InputDecoration(
          hintText: 'Secret text…',
          border: InputBorder.none,
        ),
      );
    }
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          const Icon(Icons.lock_outline, size: 40),
          const SizedBox(height: 12),
          const Text(
            'This secret is hidden. Enter your vault PIN to reveal and edit it.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pin,
            obscureText: true,
            keyboardType: TextInputType.number,
            enabled: !_busy,
            onSubmitted: (_) => _reveal(),
            decoration: const InputDecoration(
              labelText: 'Vault PIN',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _reveal,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Reveal'),
          ),
        ],
      ),
    );
  }
}
