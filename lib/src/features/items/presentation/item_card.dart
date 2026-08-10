import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:highlight/highlight.dart' show highlight;

import 'package:archespace_mobile/src/features/items/domain/item_clipboard.dart';
import 'package:archespace_mobile/src/features/items/domain/item_types.dart';
import 'package:archespace_mobile/src/features/items/domain/space_item.dart';
import 'package:archespace_mobile/src/shared/widgets/select_box.dart';

/// Renders one space item as a card: a type badge, title, and a type-specific
/// body preview. Tapping the card opens the full editor; the action menu and
/// copy button handle per-item actions.
class ItemCard extends StatefulWidget {
  const ItemCard({
    super.key,
    required this.item,
    this.onTap,
    this.onTogglePin,
    this.onDuplicate,
    this.onMove,
    this.onArchive,
    this.onDelete,
    this.onExport,
    this.selectMode = false,
    this.selected = false,
    this.onSelectToggle,
  });

  final SpaceItem item;
  final VoidCallback? onTap;
  final VoidCallback? onTogglePin;
  final VoidCallback? onDuplicate;
  final VoidCallback? onMove;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;
  final VoidCallback? onExport;
  final bool selectMode;
  final bool selected;
  final VoidCallback? onSelectToggle;

  @override
  State<ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<ItemCard> {
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final selectMode = widget.selectMode;
    final selected = widget.selected;
    final onTap = widget.onTap;
    final onSelectToggle = widget.onSelectToggle;
    final onTogglePin = widget.onTogglePin;
    final onDuplicate = widget.onDuplicate;
    final onMove = widget.onMove;
    final onArchive = widget.onArchive;
    final onDelete = widget.onDelete;
    final onExport = widget.onExport;
    final scheme = Theme.of(context).colorScheme;
    // Border tracks pinned/selected (accent) or a subtle default, matching the
    // web item card and the mobile space card. Pinned/selected also gets a
    // faint accent tint (web: bg-accent/5).
    final accent = selected || item.pinned;
    final borderColor = accent ? scheme.primary : scheme.outlineVariant;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      color: accent
          ? Color.alphaBlend(
              scheme.primary.withValues(alpha: 0.05),
              scheme.surface,
            )
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: selected ? 2 : 1.5),
      ),
      child: InkWell(
        onTap: selectMode ? onSelectToggle : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (item.pinned)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        Icons.push_pin,
                        size: 16,
                        color: scheme.primary,
                        semanticLabel: 'Pinned',
                      ),
                    ),
                  if (itemTypeDef(item.type) != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: scheme.primary.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          itemTypeDef(item.type)!.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      item.title.isEmpty ? 'Untitled' : item.title,
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!selectMode)
                    SizedBox(
                      height: 32,
                      width: 32,
                      child: IconButton(
                        icon: Icon(
                          _collapsed ? Icons.expand_more : Icons.expand_less,
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        tooltip: _collapsed ? 'Expand' : 'Collapse',
                        onPressed: () =>
                            setState(() => _collapsed = !_collapsed),
                      ),
                    ),
                  if (!selectMode && isCopyableType(item.type))
                    SizedBox(
                      height: 32,
                      width: 32,
                      child: IconButton(
                        icon: const Icon(Icons.content_copy, size: 16),
                        padding: EdgeInsets.zero,
                        tooltip: 'Copy',
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: itemClipboardText(item)),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Copied to clipboard'),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  if (!selectMode &&
                      (onTogglePin != null ||
                          onDuplicate != null ||
                          onMove != null ||
                          onArchive != null ||
                          onExport != null ||
                          onDelete != null))
                    SizedBox(
                      height: 32,
                      width: 32,
                      child: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 18),
                        padding: EdgeInsets.zero,
                        tooltip: 'Item actions',
                        onSelected: (value) {
                          if (value == 'pin') onTogglePin?.call();
                          if (value == 'duplicate') onDuplicate?.call();
                          if (value == 'move') onMove?.call();
                          if (value == 'export') onExport?.call();
                          if (value == 'archive') onArchive?.call();
                          if (value == 'delete') onDelete?.call();
                        },
                        itemBuilder: (context) => [
                          if (onTogglePin != null)
                            PopupMenuItem(
                              value: 'pin',
                              child: Text(item.pinned ? 'Unpin' : 'Pin'),
                            ),
                          if (onDuplicate != null)
                            const PopupMenuItem(
                              value: 'duplicate',
                              child: Text('Duplicate'),
                            ),
                          if (onMove != null)
                            const PopupMenuItem(
                              value: 'move',
                              child: Text('Move to space'),
                            ),
                          if (onExport != null)
                            const PopupMenuItem(
                              value: 'export',
                              child: Text('Export PDF'),
                            ),
                          if (onArchive != null)
                            const PopupMenuItem(
                              value: 'archive',
                              child: Text('Archive'),
                            ),
                          if (onDelete != null)
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                        ],
                      ),
                    ),
                  if (selectMode)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: SelectBox(selected: selected),
                    ),
                ],
              ),
              if (!_collapsed) ...[
                const SizedBox(height: 10),
                Divider(height: 1, color: scheme.outlineVariant),
                const SizedBox(height: 10),
                _ItemBody(item: item),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemBody extends StatelessWidget {
  const _ItemBody({required this.item});

  final SpaceItem item;

  @override
  Widget build(BuildContext context) {
    final c = item.content;
    switch (item.type) {
      case 'textbox':
        final plain = (c['text'] ?? '').toString();
        // Non-selectable so a tap on the body opens the item (via the card's
        // InkWell) instead of starting a text selection. Use the copy button
        // in the header to copy.
        return plain.isEmpty ? const _Empty() : Text(plain);
      case 'markdown':
        final md = (c['text'] ?? '').toString();
        return md.isEmpty
            ? const _Empty()
            : MarkdownBody(data: md, selectable: false);
      case 'code':
        return _Code(code: (c['code'] ?? '').toString());
      case 'menu_list':
        return _ListView(items: _listTexts(c), ordered: false);
      case 'numbered_list':
        return _ListView(items: _listTexts(c), ordered: true);
      case 'checkbox_list':
        return _Checklist(items: (c['items'] as List?) ?? const []);
      case 'card_list':
        return _Cards(items: (c['items'] as List?) ?? const []);
      case 'secret':
        return const _Masked();
      case 'table':
        return _TableView(columns: _columns(c), rows: _rows(c));
      case 'draw':
        return _Drawing(strokes: (c['strokes'] as List?) ?? const []);
      default:
        return Text('Unsupported item type: ${item.type}');
    }
  }
}

// ── Renderers ─────────────────────────────────────────────

class _ListView extends StatelessWidget {
  const _ListView({required this.items, required this.ordered});

  final List<String> items;
  final bool ordered;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _Empty();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 26, child: Text(ordered ? '${i + 1}.' : '•')),
                Expanded(child: Text(items[i])),
              ],
            ),
          ),
      ],
    );
  }
}

class _Checklist extends StatelessWidget {
  const _Checklist({required this.items});

  final List<dynamic> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _Empty();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final raw in items)
          if (raw is Map)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    (raw['checked'] ?? false) == true
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      (raw['text'] ?? '').toString(),
                      style: (raw['checked'] ?? false) == true
                          ? const TextStyle(
                              decoration: TextDecoration.lineThrough,
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class _Cards extends StatelessWidget {
  const _Cards({required this.items});

  final List<dynamic> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _Empty();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final raw in items)
          if (raw is Map)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((raw['title'] ?? '').toString().isNotEmpty)
                    Text(
                      raw['title'].toString(),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  if ((raw['description'] ?? '').toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(raw['description'].toString()),
                    ),
                ],
              ),
            ),
      ],
    );
  }
}

class _Masked extends StatelessWidget {
  const _Masked();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.lock_outline, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '•••••• hidden secret (tap to reveal)',
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
        ),
      ],
    );
  }
}

/// Read-only code preview with auto-detected syntax highlighting. The global
/// `highlight` instance registers all languages, so `autoDetection` works with
/// no language picker; when nothing is detected it falls back to plain mono.
class _Code extends StatelessWidget {
  const _Code({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    if (code.trim().isEmpty) return const _Empty();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF161A22) : const Color(0xFFF6F8FA);
    final baseColor = dark ? const Color(0xFFD5DAE2) : const Color(0xFF24292E);
    const mono = TextStyle(
      fontFamily: 'monospace',
      fontSize: 12.5,
      height: 1.5,
    );

    final lang = highlight.parse(code, autoDetection: true).language;
    final Widget body = (lang == null || lang.isEmpty)
        ? Padding(
            padding: const EdgeInsets.all(12),
            child: Text(code, style: mono.copyWith(color: baseColor)),
          )
        : HighlightView(
            code,
            language: lang,
            theme: _codeTheme(baseColor),
            padding: const EdgeInsets.all(12),
            textStyle: mono,
          );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: body,
        ),
      ),
    );
  }
}

/// A transparent-background highlight theme (token colours match the web
/// palette) so the surrounding container colour shows through.
Map<String, TextStyle> _codeTheme(Color base) => {
  'root': TextStyle(color: base, backgroundColor: Colors.transparent),
  'comment': const TextStyle(
    color: Color(0xFF7D8590),
    fontStyle: FontStyle.italic,
  ),
  'quote': const TextStyle(
    color: Color(0xFF7D8590),
    fontStyle: FontStyle.italic,
  ),
  'keyword': const TextStyle(color: Color(0xFFA855F7)),
  'selector-tag': const TextStyle(color: Color(0xFFA855F7)),
  'literal': const TextStyle(color: Color(0xFFA855F7)),
  'type': const TextStyle(color: Color(0xFFA855F7)),
  'name': const TextStyle(color: Color(0xFFA855F7)),
  'string': const TextStyle(color: Color(0xFF2F9E57)),
  'regexp': const TextStyle(color: Color(0xFF2F9E57)),
  'addition': const TextStyle(color: Color(0xFF2F9E57)),
  'number': const TextStyle(color: Color(0xFFD97706)),
  'symbol': const TextStyle(color: Color(0xFFD97706)),
  'bullet': const TextStyle(color: Color(0xFFD97706)),
  'link': const TextStyle(color: Color(0xFFD97706)),
  'title': const TextStyle(color: Color(0xFF2563EB)),
  'built_in': const TextStyle(color: Color(0xFF2563EB)),
  'attr': const TextStyle(color: Color(0xFF0891B2)),
  'attribute': const TextStyle(color: Color(0xFF0891B2)),
  'variable': const TextStyle(color: Color(0xFF0891B2)),
  'template-variable': const TextStyle(color: Color(0xFF0891B2)),
  'tag': const TextStyle(color: Color(0xFFE11D48)),
  'selector-id': const TextStyle(color: Color(0xFFE11D48)),
  'selector-class': const TextStyle(color: Color(0xFFE11D48)),
  'deletion': const TextStyle(color: Color(0xFFE11D48)),
  'meta': const TextStyle(color: Color(0xFF8B5CF6)),
  'emphasis': const TextStyle(fontStyle: FontStyle.italic),
  'strong': const TextStyle(fontWeight: FontWeight.w600),
};

class _TableView extends StatelessWidget {
  const _TableView({required this.columns, required this.rows});

  final List<String> columns;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    final colCount = columns.isNotEmpty
        ? columns.length
        : (rows.isNotEmpty ? rows.first.length : 0);
    if (colCount == 0) return const _Empty();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          for (var i = 0; i < colCount; i++)
            DataColumn(
              label: Text(
                i < columns.length && columns[i].isNotEmpty ? columns[i] : ' ',
              ),
            ),
        ],
        rows: [
          for (final r in rows)
            DataRow(
              cells: [
                for (var i = 0; i < colCount; i++)
                  DataCell(Text(i < r.length ? r[i] : '')),
              ],
            ),
        ],
      ),
    );
  }
}

class _Drawing extends StatelessWidget {
  const _Drawing({required this.strokes});

  final List<dynamic> strokes;

  @override
  Widget build(BuildContext context) {
    if (strokes.isEmpty) return const _Empty();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: 1000 / 600,
        child: ColoredBox(
          color: Colors.white,
          child: CustomPaint(
            painter: _StrokePainter(strokes),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _StrokePainter extends CustomPainter {
  _StrokePainter(this.strokes);

  final List<dynamic> strokes;
  static const double _vw = 1000;
  static const double _vh = 600;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      if (s is! Map) continue;
      final pts = (s['points'] as List?) ?? const [];
      if (pts.isEmpty) continue;
      final paint = Paint()
        ..color = _parseColor(s['color'], const Color(0xFF1E293B))
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth =
            ((s['size'] as num?)?.toDouble() ?? 8) * size.width / _vw;

      final path = Path();
      var started = false;
      for (final p in pts) {
        if (p is! List || p.length < 2) continue;
        final x = (p[0] as num).toDouble() / _vw * size.width;
        final y = (p[1] as num).toDouble() / _vh * size.height;
        if (!started) {
          path.moveTo(x, y);
          started = true;
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StrokePainter oldDelegate) =>
      oldDelegate.strokes != strokes;
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Empty',
      style: TextStyle(
        color: Theme.of(context).hintColor,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

// ── Content extractors ────────────────────────────────────

List<String> _listTexts(Map<String, dynamic> c) =>
    ((c['items'] as List?) ?? const [])
        .map((e) => (e is Map ? (e['text'] ?? '') : '').toString())
        .toList();

List<String> _columns(Map<String, dynamic> c) =>
    ((c['columns'] as List?) ?? const [])
        .map((e) => (e ?? '').toString())
        .toList();

List<List<String>> _rows(Map<String, dynamic> c) =>
    ((c['rows'] as List?) ?? const [])
        .map(
          (r) => ((r as List?) ?? const [])
              .map((e) => (e ?? '').toString())
              .toList(),
        )
        .toList();

Color _parseColor(Object? hex, Color fallback) {
  if (hex is String && hex.startsWith('#') && hex.length == 7) {
    final value = int.tryParse(hex.substring(1), radix: 16);
    if (value != null) return Color(0xFF000000 | value);
  }
  return fallback;
}
