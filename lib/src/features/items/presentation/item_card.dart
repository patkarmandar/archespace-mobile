import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'package:archespace_mobile/src/features/items/domain/space_item.dart';

/// Renders one space item as a card: title plus a type-specific body.
/// Read-only for this slice (editing comes later).
class ItemCard extends StatelessWidget {
  const ItemCard({
    super.key,
    required this.item,
    this.onTap,
    this.onTogglePin,
    this.onArchive,
    this.onDelete,
  });

  final SpaceItem item;
  final VoidCallback? onTap;
  final VoidCallback? onTogglePin;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              children: [
                if (item.pinned)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.push_pin, size: 16),
                  ),
                Expanded(
                  child: Text(
                    item.title.isEmpty ? 'Untitled' : item.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (onTogglePin != null ||
                    onArchive != null ||
                    onDelete != null)
                  SizedBox(
                    height: 32,
                    width: 32,
                    child: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 18),
                      padding: EdgeInsets.zero,
                      tooltip: 'Item actions',
                      onSelected: (value) {
                        if (value == 'pin') onTogglePin?.call();
                        if (value == 'archive') onArchive?.call();
                        if (value == 'delete') onDelete?.call();
                      },
                      itemBuilder: (context) => [
                        if (onTogglePin != null)
                          PopupMenuItem(
                            value: 'pin',
                            child: Text(item.pinned ? 'Unpin' : 'Pin'),
                          ),
                        if (onArchive != null)
                          const PopupMenuItem(
                              value: 'archive', child: Text('Archive')),
                        if (onDelete != null)
                          const PopupMenuItem(
                              value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _ItemBody(item: item),
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
        return plain.isEmpty ? const _Empty() : SelectableText(plain);
      case 'markdown':
        final md = (c['text'] ?? '').toString();
        return md.isEmpty
            ? const _Empty()
            : MarkdownBody(data: md, selectable: true);
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
                SizedBox(
                  width: 26,
                  child: Text(ordered ? '${i + 1}.' : '•'),
                ),
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
                              decoration: TextDecoration.lineThrough)
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
        ..strokeWidth = ((s['size'] as num?)?.toDouble() ?? 8) * size.width / _vw;

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
        .map((r) => ((r as List?) ?? const [])
            .map((e) => (e ?? '').toString())
            .toList())
        .toList();

Color _parseColor(Object? hex, Color fallback) {
  if (hex is String && hex.startsWith('#') && hex.length == 7) {
    final value = int.tryParse(hex.substring(1), radix: 16);
    if (value != null) return Color(0xFF000000 | value);
  }
  return fallback;
}
