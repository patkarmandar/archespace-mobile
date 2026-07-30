/// A decrypted space.
class Space {
  Space({
    required this.id,
    required this.name,
    required this.description,
    required this.pinned,
    this.tags = const [],
    this.color,
    this.itemCount = 0,
    this.pinnedCount = 0,
    this.createdAt,
  });

  final String id;
  final String name;
  final String description;
  final bool pinned;
  final List<String> tags;

  /// Preset colour id (violet/blue/green/amber/rose/slate), or null.
  final String? color;

  /// Number of (non-deleted, non-archived) items in this space, and how many
  /// of those are pinned. Computed at fetch time; 0 when unknown.
  final int itemCount;
  final int pinnedCount;
  final DateTime? createdAt;
}
