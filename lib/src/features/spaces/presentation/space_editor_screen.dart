import 'package:flutter/material.dart';

import 'package:archespace_mobile/src/features/spaces/data/space_repository.dart';
import 'package:archespace_mobile/src/features/spaces/domain/space.dart';
import 'package:archespace_mobile/src/features/spaces/domain/space_colors.dart';
import 'package:archespace_mobile/src/features/vault/application/vault_session.dart';
import 'package:archespace_mobile/src/shared/util/errors.dart';

/// Create or edit a space (name, description, colour, tags). Pass [existing] to
/// edit. Pops `true` on save so the caller can refresh.
class SpaceEditorScreen extends StatefulWidget {
  const SpaceEditorScreen({super.key, this.existing});

  final Space? existing;

  @override
  State<SpaceEditorScreen> createState() => _SpaceEditorScreenState();
}

class _SpaceEditorScreenState extends State<SpaceEditorScreen> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.existing?.description ?? '',
  );
  final TextEditingController _tagInput = TextEditingController();

  late String? _color = widget.existing?.color;
  late final List<String> _tags = List<String>.of(
    widget.existing?.tags ?? const [],
  );

  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _tagInput.dispose();
    super.dispose();
  }

  void _addTags(String raw) {
    final added = raw
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty && !_tags.contains(t));
    setState(() {
      _tags.addAll(added);
      _tagInput.clear();
    });
  }

  Future<void> _save() async {
    _addTags(_tagInput.text); // fold any pending text into tags
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a name for the space.')),
      );
      return;
    }
    setState(() => _saving = true);
    final repo = SpaceRepository(VaultSession.instance.masterKey);
    try {
      if (widget.existing != null) {
        await repo.updateSpace(
          id: widget.existing!.id,
          name: name,
          description: _description.text.trim(),
          color: _color,
          tags: _tags,
        );
      } else {
        await repo.createSpace(
          name: name,
          description: _description.text.trim(),
          color: _color,
          tags: _tags,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(saveErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing != null ? 'Edit space' : 'New space'),
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
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            _label('Colour'),
            const SizedBox(height: 8),
            _colorPicker(),
            const SizedBox(height: 20),
            _label('Tags'),
            const SizedBox(height: 8),
            _tagsEditor(),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.6,
      color: Theme.of(context).colorScheme.primary,
    ),
  );

  Widget _colorPicker() {
    final scheme = Theme.of(context).colorScheme;
    Widget dot(String? id, Color? color) {
      final isSelected = _color == id;
      return GestureDetector(
        onTap: () => setState(() => _color = id),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(
              color: isSelected ? scheme.onSurface : scheme.outlineVariant,
              width: isSelected ? 3 : 1,
            ),
          ),
          child: color == null
              ? Icon(Icons.block, size: 18, color: scheme.outline)
              : (isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : null),
        ),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        dot(null, null),
        for (final entry in kSpaceColors.entries) dot(entry.key, entry.value),
      ],
    );
  }

  Widget _tagsEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in _tags)
                  Chip(
                    label: Text(tag),
                    onDeleted: () => setState(() => _tags.remove(tag)),
                  ),
              ],
            ),
          ),
        TextField(
          controller: _tagInput,
          textInputAction: TextInputAction.done,
          onSubmitted: _addTags,
          decoration: const InputDecoration(
            hintText: 'Add a tag and press Enter',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ],
    );
  }
}
