import 'package:flutter/material.dart';

import 'package:archespace_mobile/src/features/spaces/domain/space.dart';
import 'package:archespace_mobile/src/features/spaces/domain/space_colors.dart';

/// A space rendered as a content card (matching the web): a subtle border that
/// turns accent when pinned or selected, the space colour as a top border only,
/// tag chips, pin indicator, name + chevron, and a footer with the item count
/// and an edit/delete menu.
class SpaceCard extends StatelessWidget {
  const SpaceCard({
    super.key,
    required this.space,
    required this.onTap,
    required this.onTogglePin,
    required this.onEdit,
    required this.onDuplicate,
    required this.onArchive,
    required this.onDelete,
    this.selectMode = false,
    this.selected = false,
    this.onSelectToggle,
  });

  final Space space;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onArchive;
  final VoidCallback onDelete;
  final bool selectMode;
  final bool selected;
  final VoidCallback? onSelectToggle;

  String get _countLabel =>
      '${space.itemCount} ${space.itemCount == 1 ? 'item' : 'items'}';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // The full border tracks pinned/selected (accent) or default (subtle); the
    // space colour is shown only as a top border, matching the web.
    final border = selected || space.pinned
        ? scheme.primary
        : scheme.outlineVariant;
    final topColor = spaceColor(space.color);

    return Stack(
      children: [
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: border, width: selected ? 2 : 1.5),
          ),
          child: InkWell(
            onTap: selectMode ? onSelectToggle : onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (space.tags.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final tag in space.tags.take(4))
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: scheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    tag,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          if (selectMode)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Icon(
                                selected
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                                size: 20,
                                color: selected
                                    ? scheme.primary
                                    : scheme.outline,
                              ),
                            ),
                          if (space.pinned)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Icon(
                                Icons.push_pin,
                                size: 18,
                                color: scheme.primary,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              space.name.isEmpty ? 'Untitled' : space.name,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!selectMode)
                            Icon(
                              Icons.chevron_right,
                              color: scheme.onSurfaceVariant,
                            ),
                        ],
                      ),
                      if (space.description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            space.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                    ],
                  ),
                ),
                Divider(height: 1, color: scheme.outlineVariant),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 10, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _countLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (!selectMode)
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: scheme.outlineVariant),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_horiz, size: 18),
                            tooltip: 'Space actions',
                            onSelected: (value) {
                              if (value == 'pin') onTogglePin();
                              if (value == 'edit') onEdit();
                              if (value == 'duplicate') onDuplicate();
                              if (value == 'archive') onArchive();
                              if (value == 'delete') onDelete();
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'pin',
                                child: Text(space.pinned ? 'Unpin' : 'Pin'),
                              ),
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              const PopupMenuItem(
                                value: 'duplicate',
                                child: Text('Duplicate'),
                              ),
                              const PopupMenuItem(
                                value: 'archive',
                                child: Text('Archive'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Space colour as a top border only (matching the web), drawn over the
        // card's own border and clipped to the rounded top corners.
        if (topColor != null)
          Positioned(
            top: 6,
            left: 12,
            right: 12,
            child: IgnorePointer(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: Container(height: 3, color: topColor),
              ),
            ),
          ),
      ],
    );
  }
}
