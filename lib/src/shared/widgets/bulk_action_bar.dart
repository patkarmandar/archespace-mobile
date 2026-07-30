import 'package:flutter/material.dart';

class BulkAction {
  const BulkAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
}

/// Bottom bar shown in selection mode: a selected count plus the batch actions.
class BulkActionBar extends StatelessWidget {
  const BulkActionBar({super.key, required this.count, required this.actions});

  final int count;
  final List<BulkAction> actions;

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 8),
            child: Text('$count selected'),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                children: [
                  for (final action in actions)
                    IconButton(
                      onPressed: count == 0 ? null : action.onPressed,
                      icon: Icon(action.icon),
                      tooltip: action.label,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
