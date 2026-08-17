import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:archespace_mobile/src/features/items/domain/draw.dart';
import 'package:archespace_mobile/src/features/items/domain/space_item.dart';

/// Builds a PDF for a whole space or a single item, per item type. Mirrors the
/// web PDF export's content structure.
class PdfExporter {
  const PdfExporter._();

  static Future<Uint8List> buildSpace(
    String name,
    List<SpaceItem> items,
  ) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(level: 0, text: name.isEmpty ? 'Space' : name),
          if (items.isEmpty) pw.Text('This space has no items.'),
          for (final item in items) _section(item),
        ],
      ),
    );
    return doc.save();
  }

  static Future<Uint8List> buildItem(SpaceItem item) async {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(build: (context) => [_section(item)]));
    return doc.save();
  }

  static pw.Widget _section(SpaceItem item) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 8),
        pw.Text(
          item.title.isEmpty ? 'Untitled' : item.title,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        _body(item),
        pw.Divider(),
      ],
    );
  }

  static pw.Widget _body(SpaceItem item) {
    final c = item.content;
    switch (item.type) {
      case 'textbox':
      case 'markdown':
        final text = (c['text'] ?? '').toString();
        return pw.Text(text.isEmpty ? '(empty)' : text);
      case 'code':
        final code = (c['code'] ?? '').toString();
        if (code.isEmpty) return pw.Text('(empty)');
        return pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            border: pw.Border.all(color: PdfColors.grey400),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(
            code,
            style: pw.TextStyle(
              font: pw.Font.courier(),
              fontSize: 9,
              lineSpacing: 2,
            ),
          ),
        );
      case 'menu_list':
        return _bullets(c, ordered: false);
      case 'numbered_list':
        return _bullets(c, ordered: true);
      case 'checkbox_list':
        return _checklist(c);
      case 'card_list':
        return _cards(c);
      case 'table':
        return _table(c);
      case 'secret':
        return pw.Text('•••••• (hidden secret)');
      case 'draw':
        return _drawing(c);
      default:
        return pw.SizedBox();
    }
  }

  static pw.Widget _bullets(Map<String, dynamic> c, {required bool ordered}) {
    final rows = (c['items'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => (e['text'] ?? '').toString())
        .where((t) => t.trim().isNotEmpty)
        .toList();
    if (rows.isEmpty) return pw.Text('(empty)');
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < rows.length; i++)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 1),
            child: pw.Text(ordered ? '${i + 1}. ${rows[i]}' : '• ${rows[i]}'),
          ),
      ],
    );
  }

  static pw.Widget _checklist(Map<String, dynamic> c) {
    final items = (c['items'] as List? ?? const []).whereType<Map>().toList();
    if (items.isEmpty) return pw.Text('(empty)');
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final it in items)
          pw.Text(
            '${(it['checked'] ?? false) == true ? '[x]' : '[ ]'} '
            '${(it['text'] ?? '').toString()}',
          ),
      ],
    );
  }

  static pw.Widget _cards(Map<String, dynamic> c) {
    final items = (c['items'] as List? ?? const []).whereType<Map>().toList();
    if (items.isEmpty) return pw.Text('(empty)');
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final it in items)
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 6),
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if ((it['title'] ?? '').toString().isNotEmpty)
                  pw.Text(
                    (it['title']).toString(),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                if ((it['description'] ?? '').toString().isNotEmpty)
                  pw.Text((it['description']).toString()),
              ],
            ),
          ),
      ],
    );
  }

  static pw.Widget _table(Map<String, dynamic> c) {
    final columns = (c['columns'] as List? ?? const [])
        .map((e) => (e ?? '').toString())
        .toList();
    final rows = (c['rows'] as List? ?? const [])
        .map(
          (r) => r is List
              ? r.map((e) => (e ?? '').toString()).toList()
              : <String>[],
        )
        .toList();
    if (columns.isEmpty && rows.isEmpty) return pw.Text('(empty)');
    return pw.TableHelper.fromTextArray(
      headers: columns.isEmpty ? null : columns,
      data: rows,
    );
  }

  static pw.Widget _drawing(Map<String, dynamic> c) {
    final strokes = c['strokes'] as List? ?? const [];
    if (strokes.isEmpty) return pw.Text('(empty drawing)');
    final logical = drawLogicalSize(c['orientation']);
    final scale = 360 / max(logical.width, logical.height);
    return pw.SizedBox(
      width: logical.width * scale,
      height: logical.height * scale,
      child: pw.SvgImage(svg: _drawSvg(strokes, logical)),
    );
  }

  static String _drawSvg(List<dynamic> strokes, Size logical) {
    final w = logical.width.toInt();
    final h = logical.height.toInt();
    final buffer = StringBuffer(
      '<svg viewBox="0 0 $w $h" xmlns="http://www.w3.org/2000/svg">'
      '<rect width="$w" height="$h" fill="white"/>',
    );
    for (final s in strokes) {
      if (s is! Map) continue;
      final pts = s['points'] as List? ?? const [];
      if (pts.isEmpty) continue;
      final color = (s['color'] ?? '#1e293b').toString();
      final size = (s['size'] as num?)?.toDouble() ?? 8;
      final d = StringBuffer();
      var started = false;
      for (final p in pts) {
        if (p is! List || p.length < 2) continue;
        final x = (p[0] as num).toDouble();
        final y = (p[1] as num).toDouble();
        d.write(started ? ' L $x $y' : 'M $x $y');
        started = true;
      }
      buffer.write(
        '<path d="$d" stroke="$color" stroke-width="$size" '
        'fill="none" stroke-linecap="round" stroke-linejoin="round"/>',
      );
    }
    buffer.write('</svg>');
    return buffer.toString();
  }
}
