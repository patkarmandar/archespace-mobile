import 'package:flutter/material.dart';

const String kSortDefault = 'default';
const String kSortName = 'name';
const String kSortNewest = 'newest';

/// Sort [list] by [mode]. Pinned entries always stay on top (matching the web),
/// then name (case-insensitive) or newest (created_at descending). `default`
/// keeps the incoming (position) order.
List<T> applySort<T>(
  List<T> list,
  String mode, {
  required String Function(T) name,
  required DateTime? Function(T) createdAt,
  required bool Function(T) pinned,
}) {
  if (mode == kSortDefault) return list;
  final sorted = List<T>.of(list);
  sorted.sort((a, b) {
    final pa = pinned(a);
    final pb = pinned(b);
    if (pa != pb) return pa ? -1 : 1;
    if (mode == kSortName) {
      return name(a).toLowerCase().compareTo(name(b).toLowerCase());
    }
    final ca = createdAt(a);
    final cb = createdAt(b);
    if (ca == null && cb == null) return 0;
    if (ca == null) return 1;
    if (cb == null) return -1;
    return cb.compareTo(ca); // newest first
  });
  return sorted;
}

/// App-bar sort dropdown with a check on the active option.
class SortMenu extends StatelessWidget {
  const SortMenu({super.key, required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.sort),
      tooltip: 'Sort',
      onSelected: onChanged,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      menuPadding: const EdgeInsets.symmetric(vertical: 4),
      itemBuilder: (context) => [
        _sortItem(kSortDefault, 'Default order'),
        _sortItem(kSortName, 'Name'),
        _sortItem(kSortNewest, 'Newest'),
      ],
    );
  }

  /// A compact menu row (matching the 3-dot action menus) with an inline check
  /// on the active option instead of a bulkier CheckedPopupMenuItem.
  PopupMenuItem<String> _sortItem(String option, String label) {
    return PopupMenuItem<String>(
      value: option,
      height: 40,
      child: Row(
        children: [
          Expanded(child: Text(label)),
          if (value == option) const Icon(Icons.check, size: 18),
        ],
      ),
    );
  }
}
