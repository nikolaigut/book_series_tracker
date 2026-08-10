class ReadingSeries {
  final int? id;
  final String name;
  final String? author;
  final DateTime createdAt;

  const ReadingSeries({
    this.id,
    required this.name,
    this.author,
    required this.createdAt,
  });

  ReadingSeries copyWith({
    int? id,
    String? name,
    String? author,
    DateTime? createdAt,
  }) {
    return ReadingSeries(
      id: id ?? this.id,
      name: name ?? this.name,
      author: author ?? this.author,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'author': author,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory ReadingSeries.fromMap(Map<String, dynamic> map) {
    return ReadingSeries(
      id: map['id'] as int?,
      name: map['name'] as String,
      author: map['author'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    );
  }
}
