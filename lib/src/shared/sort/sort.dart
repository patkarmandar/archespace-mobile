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
      itemBuilder: (context) => [
        CheckedPopupMenuItem(
          value: kSortDefault,
          checked: value == kSortDefault,
          child: const Text('Default order'),
        ),
        CheckedPopupMenuItem(
          value: kSortName,
          checked: value == kSortName,
          child: const Text('Name'),
        ),
        CheckedPopupMenuItem(
          value: kSortNewest,
          checked: value == kSortNewest,
          child: const Text('Newest'),
        ),
      ],
    );
  }
}
