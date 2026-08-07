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
        // Space colour as the card's top border, curved around the top corners
        // to match the web (a coloured top border on a rounded card).
        if (topColor != null)
          Positioned.fill(
            child: IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: CustomPaint(
                  painter: _TopBorderPainter(color: topColor, radius: 16),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Fills the top edge and the two top corners of the card's rounded rectangle
/// as a crescent that is [_thickness]px at the top and tapers to a point where
/// it meets each side, so the space colour reads as a curved coloured top
/// border that fades out smoothly (matching the web) rather than ending
/// abruptly at full thickness.
class _TopBorderPainter extends CustomPainter {
  _TopBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const double _thickness = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final r = radius;
    const t = _thickness;
    final ri = r - t;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    // A uniform t-px band hugging the rounded top: outer edge follows the card's
    // rounded top corners (left tangent → top → right tangent); the inner edge
    // is a concentric arc t px inside, so the band stays an even thickness all
    // the way around the corners and ends flush where the side border begins.
    final path = Path()
      ..moveTo(0, r)
      ..arcToPoint(Offset(r, 0), radius: Radius.circular(r))
      ..lineTo(w - r, 0)
      ..arcToPoint(Offset(w, r), radius: Radius.circular(r))
      ..lineTo(w - t, r)
      ..arcToPoint(
        Offset(w - r, t),
        radius: Radius.circular(ri),
        clockwise: false,
      )
      ..lineTo(r, t)
      ..arcToPoint(Offset(t, r), radius: Radius.circular(ri), clockwise: false)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TopBorderPainter old) =>
      old.color != color || old.radius != radius;
}
