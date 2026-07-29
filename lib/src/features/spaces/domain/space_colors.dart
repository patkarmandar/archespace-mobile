import 'package:flutter/material.dart';

/// Space accent presets, matching the web `SPACE_COLORS`.
const Map<String, Color> kSpaceColors = {
  'violet': Color(0xFF7C6AF7),
  'blue': Color(0xFF60A5FA),
  'green': Color(0xFF34D399),
  'amber': Color(0xFFFBBF24),
  'rose': Color(0xFFFB7185),
  'slate': Color(0xFF94A3B8),
};

Color? spaceColor(String? id) => id == null ? null : kSpaceColors[id];
