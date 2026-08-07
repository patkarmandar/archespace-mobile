import 'package:flutter/material.dart';

/// A thin banner shown when a list is displaying cached data because the
/// network was unavailable.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.secondaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.cloud_off, size: 16, color: scheme.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Offline — showing saved data',
              style: TextStyle(
                color: scheme.onSecondaryContainer,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
