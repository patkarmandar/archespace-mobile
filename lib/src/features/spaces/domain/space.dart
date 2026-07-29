/// A decrypted space (only the fields the UI currently displays).
class Space {
  Space({
    required this.id,
    required this.name,
    required this.description,
    required this.pinned,
  });

  final String id;
  final String name;
  final String description;
  final bool pinned;
}
