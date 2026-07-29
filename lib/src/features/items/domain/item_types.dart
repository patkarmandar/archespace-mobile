import 'package:flutter/material.dart';

/// Definition of an item type: label, icon, and whether a mobile editor exists
/// yet. Editors are being added one type at a time; [editable] gates which
/// types show in the "add item" picker and open for editing on tap.
class ItemTypeDef {
  const ItemTypeDef({
    required this.type,
    required this.label,
    required this.description,
    required this.icon,
    this.editable = false,
  });

  final String type;
  final String label;
  final String description;
  final IconData icon;
  final bool editable;
}

const List<ItemTypeDef> kItemTypes = [
  ItemTypeDef(
    type: 'textbox',
    label: 'Note',
    description: 'Free-form plain text',
    icon: Icons.notes,
    editable: true,
  ),
  ItemTypeDef(
    type: 'markdown',
    label: 'Markdown',
    description: 'Rich text with markdown',
    icon: Icons.code,
    editable: true,
  ),
  ItemTypeDef(
    type: 'menu_list',
    label: 'List',
    description: 'Simple bullet list',
    icon: Icons.list,
    editable: true,
  ),
  ItemTypeDef(
    type: 'numbered_list',
    label: 'Numbered list',
    description: 'Ordered list',
    icon: Icons.format_list_numbered,
    editable: true,
  ),
  ItemTypeDef(
    type: 'checkbox_list',
    label: 'Checklist',
    description: 'Items with checkboxes',
    icon: Icons.checklist,
    editable: true,
  ),
  ItemTypeDef(
    type: 'card_list',
    label: 'Cards',
    description: 'Title and description pairs',
    icon: Icons.view_agenda_outlined,
    editable: true,
  ),
  ItemTypeDef(
    type: 'table',
    label: 'Table',
    description: 'Rows and columns of text',
    icon: Icons.table_chart_outlined,
  ),
  ItemTypeDef(
    type: 'secret',
    label: 'Secret',
    description: 'PIN-protected hidden text',
    icon: Icons.lock_outline,
  ),
  ItemTypeDef(
    type: 'draw',
    label: 'Drawing',
    description: 'Freehand sketch',
    icon: Icons.brush_outlined,
  ),
];

ItemTypeDef? itemTypeDef(String type) {
  for (final def in kItemTypes) {
    if (def.type == type) return def;
  }
  return null;
}

bool isEditableType(String type) => itemTypeDef(type)?.editable ?? false;

/// The starting content for a newly created item, matching the web defaults.
Map<String, dynamic> defaultContentFor(String type) {
  switch (type) {
    case 'textbox':
    case 'markdown':
      return {'text': ''};
    case 'menu_list':
    case 'numbered_list':
    case 'card_list':
      return {'items': <dynamic>[]};
    case 'checkbox_list':
      return {
        'items': [
          {'id': _newId(), 'text': '', 'checked': false},
        ],
      };
    case 'table':
      return {
        'columns': ['', ''],
        'rows': [
          ['', ''],
          ['', ''],
        ],
      };
    case 'secret':
      return {'secret': true, 'cipher': ''};
    case 'draw':
      return {'strokes': <dynamic>[]};
    default:
      return <String, dynamic>{};
  }
}

String _newId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);
