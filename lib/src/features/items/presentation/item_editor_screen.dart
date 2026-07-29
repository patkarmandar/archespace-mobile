import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:archespace_mobile/src/features/items/data/item_repository.dart';
import 'package:archespace_mobile/src/features/items/domain/item_types.dart';
import 'package:archespace_mobile/src/features/items/domain/space_item.dart';
import 'package:archespace_mobile/src/features/vault/application/vault_session.dart';

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
  late final TextEditingController _title =
      TextEditingController(text: widget.existing?.title ?? '');
  late final Map<String, dynamic> _content = _initialContent();

  bool _saving = false;

  Map<String, dynamic> _initialContent() {
    final source = widget.existing?.content ?? defaultContentFor(widget.type);
    // Deep copy so editing never mutates the item still shown in the list.
    return jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final repo = ItemRepository(VaultSession.instance.masterKey);
    try {
      if (widget.existing != null) {
        await repo.updateItem(
          id: widget.existing!.id,
          title: _title.text.trim(),
          content: _content,
        );
      } else {
        await repo.createItem(
          spaceId: widget.spaceId,
          type: widget.type,
          title: _title.text.trim(),
          content: _content,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save. Check your connection.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = itemTypeDef(widget.type)?.label ?? 'Item';
    return Scaffold(
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
                  onPressed: _save,
                  icon: const Icon(Icons.check),
                  tooltip: 'Save',
                ),
        ],
      ),
      body: Padding(
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
    );
  }

  Widget _buildBody() {
    switch (widget.type) {
      case 'textbox':
      case 'markdown':
        return _NoteEditor(content: _content);
      case 'menu_list':
      case 'numbered_list':
        return _ListEditor(
          content: _content,
          ordered: widget.type == 'numbered_list',
        );
      default:
        return Center(
          child: Text('Editing ${widget.type} is not available yet.'),
        );
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
  late final TextEditingController _text =
      TextEditingController(text: (widget.content['text'] ?? '').toString());

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

/// Editable rows for `menu_list` / `numbered_list` (`{ items: [{id, text}] }`).
/// Add, edit, remove, and drag to reorder. [ordered] only changes the leading
/// marker (number vs bullet).
class _ListEditor extends StatefulWidget {
  const _ListEditor({required this.content, required this.ordered});

  final Map<String, dynamic> content;
  final bool ordered;

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
    setState(() => _items.add({'id': _uid(), 'text': ''}));
  }

  void _remove(int index) {
    final id = _items[index]['id'] as String;
    setState(() => _items.removeAt(index));
    _controllers.remove(id)?.dispose();
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
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
            onReorder: _reorder,
            itemBuilder: (context, index) {
              final item = _items[index];
              return Padding(
                key: ValueKey(item['id']),
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        widget.ordered ? '${index + 1}.' : '•',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controllerFor(item),
                        onChanged: (value) => item['text'] = value,
                        minLines: 1,
                        maxLines: null,
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
                        child: Icon(Icons.drag_handle, size: 18),
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
