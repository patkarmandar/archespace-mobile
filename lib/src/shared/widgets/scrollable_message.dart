import 'package:flutter/material.dart';

/// A centered message that still scrolls, so it works as a `RefreshIndicator`
/// child (pull-to-refresh needs a scrollable that can overscroll even when the
/// content is short). Used for empty / error states.
class ScrollableMessage extends StatelessWidget {
  const ScrollableMessage(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(text, textAlign: TextAlign.center),
            ),
          ),
        ),
      ),
    );
  }
}
