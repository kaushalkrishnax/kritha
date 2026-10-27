/// A persisted conversation session.
class ChatSession {
  const ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.pinned = false,
    this.archived = false,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool pinned;
  final bool archived;

  ChatSession copyWith({
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? pinned,
    bool? archived,
  }) {
    return ChatSession(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pinned: pinned ?? this.pinned,
      archived: archived ?? this.archived,
    );
  }
}
