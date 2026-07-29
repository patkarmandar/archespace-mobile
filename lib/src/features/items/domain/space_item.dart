/// A decrypted item within a space. [content] is the decrypted JSON object,
/// whose shape depends on [type] (see the web item type definitions).
class SpaceItem {
  SpaceItem({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.pinned,
  });

  final String id;
  final String type;
  final String title;
  final Map<String, dynamic> content;
  final bool pinned;
}
