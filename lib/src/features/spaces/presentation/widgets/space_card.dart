import 'package:flutter/material.dart';

import 'package:archespace_mobile/src/features/spaces/domain/space.dart';
import 'package:archespace_mobile/src/features/spaces/domain/space_colors.dart';
import 'package:archespace_mobile/src/shared/widgets/select_box.dart';

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
    this.margin,
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
  final EdgeInsetsGeometry? margin;

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
          margin:
              margin ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                      Row(
                        children: [
                          if (space.pinned)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Icon(
                                Icons.push_pin,
                                size: 18,
                                color: scheme.primary,
                                semanticLabel: 'Pinned',
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
                          if (selectMode)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: SelectBox(selected: selected),
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
                      if (space.tags.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
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
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: scheme.outlineVariant,
                ),
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
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SizedBox(
                            height: 28,
                            width: 28,
                            child: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_horiz, size: 16),
                              iconSize: 16,
                              padding: EdgeInsets.zero,
                              tooltip: 'Space actions',
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              menuPadding: const EdgeInsets.symmetric(
                                vertical: 4,
                              ),
                              onSelected: (value) {
                                if (value == 'pin') onTogglePin();
                                if (value == 'edit') onEdit();
                                if (value == 'duplicate') onDuplicate();
                                if (value == 'archive') onArchive();
                                if (value == 'delete') onDelete();
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  height: 40,
                                  value: 'pin',
                                  child: Text(space.pinned ? 'Unpin' : 'Pin'),
                                ),
                                const PopupMenuItem(
                                  height: 40,
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                const PopupMenuItem(
                                  height: 40,
                                  value: 'duplicate',
                                  child: Text('Duplicate'),
                                ),
                                const PopupMenuItem(
                                  height: 40,
                                  value: 'archive',
                                  child: Text('Archive'),
                                ),
                                const PopupMenuItem(
                                  height: 40,
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                              ],
                            ),
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
                padding:
                    margin ??
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

/// Fills the space colour as a curved top border: [_thickness]px across the top
/// and around the upper part of each corner, then tapering to a gradual point
/// as it curves down toward the sides (rather than ending in a straight cut).
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
    const s45 = 0.70710678; // sin/cos 45° — band is full thickness here
    const sTip = 0.92718385; // sin 68° — outer point where the band tapers out
    const cTip = 0.37460659; // cos 68°
    // Inner edge stays a concentric band down to the 45° diagonal; the outer
    // edge continues a little further, and the two meet so each end narrows to a
    // gradual point instead of a straight diagonal cut.
    final iLeft = Offset(r - ri * s45, r - ri * s45);
    final iRight = Offset(w - (r - ri * s45), r - ri * s45);
    final tipLeft = Offset(r * (1 - sTip), r * (1 - cTip));
    final tipRight = Offset(w - r * (1 - sTip), r * (1 - cTip));

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final path = Path()
      ..moveTo(tipLeft.dx, tipLeft.dy)
      ..arcToPoint(Offset(r, 0), radius: Radius.circular(r))
      ..lineTo(w - r, 0)
      ..arcToPoint(tipRight, radius: Radius.circular(r))
      ..lineTo(iRight.dx, iRight.dy)
      ..arcToPoint(
        Offset(w - r, t),
        radius: Radius.circular(ri),
        clockwise: false,
      )
      ..lineTo(r, t)
      ..arcToPoint(iLeft, radius: Radius.circular(ri), clockwise: false)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TopBorderPainter old) =>
      old.color != color || old.radius != radius;
}
