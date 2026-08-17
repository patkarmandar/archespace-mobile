import 'dart:math';
import 'dart:ui';

/// Logical drawing space (mirrors the web `drawing.js`). Points are stored in
/// this coordinate space and scaled to the rendered canvas.
const double kDrawViewW = 1000;
const double kDrawViewH = 600;

/// Logical canvas size for the saved orientation ('portrait' swaps W/H).
Size drawLogicalSize(Object? orientation) => orientation == 'portrait'
    ? const Size(kDrawViewH, kDrawViewW)
    : const Size(kDrawViewW, kDrawViewH);

/// Trace a shape (line / rect / ellipse) from [a] to [b] as a dense point list,
/// so it saves and renders as an ordinary stroke (matching the web).
List<List<double>> shapePoints(String tool, List<double> a, List<double> b) {
  const p = 0.5;
  double lerp(double u, double v, double t) => u + (v - u) * t;
  final x0 = a[0], y0 = a[1], x1 = b[0], y1 = b[1];
  if (tool == 'line') {
    return [
      for (var i = 0; i <= 16; i++)
        [lerp(x0, x1, i / 16), lerp(y0, y1, i / 16), p],
    ];
  }
  if (tool == 'rect') {
    final corners = [
      [x0, y0],
      [x1, y0],
      [x1, y1],
      [x0, y1],
      [x0, y0],
    ];
    final pts = <List<double>>[];
    for (var e = 0; e < 4; e++) {
      final ax = corners[e][0], ay = corners[e][1];
      final bx = corners[e + 1][0], by = corners[e + 1][1];
      for (var i = 0; i < 12; i++) {
        final t = i / 12;
        pts.add([lerp(ax, bx, t), lerp(ay, by, t), p]);
      }
    }
    pts.add([x0, y0, p]);
    return pts;
  }
  if (tool == 'ellipse') {
    final cx = (x0 + x1) / 2, cy = (y0 + y1) / 2;
    final rx = (x1 - x0).abs() / 2, ry = (y1 - y0).abs() / 2;
    return [
      for (var i = 0; i <= 48; i++)
        [cx + rx * cos(i / 48 * 2 * pi), cy + ry * sin(i / 48 * 2 * pi), p],
    ];
  }
  return [];
}
