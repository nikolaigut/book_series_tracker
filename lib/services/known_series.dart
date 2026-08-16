import '../models/book.dart';

/// Fallback for series that are not represented correctly by the public
/// OpenLibrary/Libex APIs (e.g. German editions with different titles).
class KnownSeries {
  static final List<({List<String> queries, List<Book> books})> _entries = [
    (
      queries: [
        'girl goddess queen',
        'girl goddess queen mein name ist persephone',
        'mein name ist persephone',
        'die girl goddess queen reihe',
        'princess prophet saviour',
        'princess prophet saviour kassandra die prophetin der keiner glaubt',
        'kassandra die prophetin der keiner glaubt',
        'girl lover legend',
        'girl lover legend die liebe der pandora',
        'die liebe der pandora',
      ],
      books: [
        const Book(
          title: 'Girl, Goddess, Queen: Mein Name ist Persephone',
          author: 'Bea Fitzgerald',
          isbn: '9783570180983',
          publishYear: 2023,
          orderIndex: 1,
        ),
        const Book(
          title: 'Princess, Prophet, Saviour: Kassandra, die Prophetin, der keiner glaubt',
          author: 'Bea Fitzgerald',
          isbn: '9783570180990',
          publishYear: 2024,
          orderIndex: 2,
        ),
        const Book(
          title: 'Girl, Lover, Legend – Die Liebe der Pandora',
          author: 'Bea Fitzgerald',
          isbn: '9783570181003',
          publishYear: 2025,
          orderIndex: 3,
        ),
      ],
    ),
  ];

  /// Returns the known book list when [query] matches a stored series title
  /// or one of its search aliases.
  static List<Book>? findSeries(String query) {
    final normalized = _normalize(query);
    if (normalized.isEmpty) return null;

    for (final entry in _entries) {
      for (final known in entry.queries) {
        if (normalized.contains(known) || known.contains(normalized)) {
          return entry.books;
        }
      }
      for (final book in entry.books) {
        final normalizedTitle = _normalize(book.title);
        if (normalized.contains(normalizedTitle) ||
            normalizedTitle.contains(normalized)) {
          return entry.books;
        }
      }
    }
    return null;
  }

  static String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll('ä', 'ae')
        .replaceAll('ö', 'oe')
        .replaceAll('ü', 'ue')
        .replaceAll('ß', 'ss')
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('ó', 'o')
        .replaceAll('ò', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ù', 'u')
        .replaceAll('â', 'a')
        .replaceAll('ê', 'e')
        .replaceAll('î', 'i')
        .replaceAll('ô', 'o')
        .replaceAll('û', 'u')
        .replaceAll('ç', 'c')
        .replaceAll('ñ', 'n')
        .replaceAll('í', 'i')
        .replaceAll('ì', 'i')
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
