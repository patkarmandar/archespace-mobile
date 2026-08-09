import 'package:flutter/material.dart';

/// A rounded-square selection indicator used in multi-select mode across cards.
/// Filled with the accent colour and a check when selected; a thin outline when
/// not. Mirrors the web select checkbox (a small rounded box, not a circle).
class SelectBox extends StatelessWidget {
  const SelectBox({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: selected ? 'Selected' : 'Not selected',
      selected: selected,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: selected ? scheme.primary : Colors.transparent,
          border: Border.all(
            color: selected ? scheme.primary : scheme.outline,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: selected
            ? Icon(Icons.check, size: 16, color: scheme.onPrimary)
            : null,
      ),
    );
  }
}
