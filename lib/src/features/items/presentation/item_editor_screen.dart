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
