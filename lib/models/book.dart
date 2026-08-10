class Book {
  final int? id;
  final int? seriesId;
  final String title;
  final String? author;
  final String? openLibraryKey;
  final String? isbn;
  final String? coverUrl;
  final int? publishYear;
  final int orderIndex;
  final bool read;

  const Book({
    this.id,
    this.seriesId,
    required this.title,
    this.author,
    this.openLibraryKey,
    this.isbn,
    this.coverUrl,
    this.publishYear,
    this.orderIndex = 0,
    this.read = false,
  });

  Book copyWith({
    int? id,
    int? seriesId,
    String? title,
    String? author,
    String? openLibraryKey,
    String? isbn,
    String? coverUrl,
    int? publishYear,
    int? orderIndex,
    bool? read,
  }) {
    return Book(
      id: id ?? this.id,
      seriesId: seriesId ?? this.seriesId,
      title: title ?? this.title,
      author: author ?? this.author,
      openLibraryKey: openLibraryKey ?? this.openLibraryKey,
      isbn: isbn ?? this.isbn,
      coverUrl: coverUrl ?? this.coverUrl,
      publishYear: publishYear ?? this.publishYear,
      orderIndex: orderIndex ?? this.orderIndex,
      read: read ?? this.read,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'seriesId': seriesId,
      'title': title,
      'author': author,
      'openLibraryKey': openLibraryKey,
      'isbn': isbn,
      'coverUrl': coverUrl,
      'publishYear': publishYear,
      'orderIndex': orderIndex,
      'read': read ? 1 : 0,
    };
  }

  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'] as int?,
      seriesId: map['seriesId'] as int?,
      title: map['title'] as String,
      author: map['author'] as String?,
      openLibraryKey: map['openLibraryKey'] as String?,
      isbn: map['isbn'] as String?,
      coverUrl: map['coverUrl'] as String?,
      publishYear: map['publishYear'] as int?,
      orderIndex: map['orderIndex'] as int? ?? 0,
      read: (map['read'] as int? ?? 0) == 1,
    );
  }
}
