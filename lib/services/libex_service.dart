import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/book.dart';
import 'known_series.dart';

class LibexService {
  static const String _base = 'https://libex.lostcartographer.xyz';
  static const Map<String, String> _headers = {
    'User-Agent': 'book_series_tracker/1.0',
  };

  static final RegExp _exclude = RegExp(
    r'(?:^|\s)(?:coloring|cookbook|cook book|recipe book|boxset|boxed set|box set|'
    r'collection|collectors|omnibus|anthology|journal|workbook|activity book|'
    r'sticker|poster|map book|companion|official|merchandise|play|drama|'
    r'full[-\s]cast|dramatized|dramatised|abridged|movie|tv|behind the scenes|'
    r'prelude|prequel|deleted|short story|0\.5|1\.5|2\.5|3\.5|4\.5|5\.5|6\.5|7\.5|8\.5|9\.5)'
    r'(?:\s|$|[,;:!. )\]])',
    caseSensitive: false,
  );

  Future<List<Book>> searchSeriesBooks(String seriesName) async {
    final trimmed = seriesName.trim();
    if (trimmed.isEmpty) return [];

    final known = KnownSeries.findSeries(normalizeForSearch(trimmed));
    if (known != null) return known;

    final uri = Uri.parse('$_base/series').replace(
      queryParameters: {'name': trimmed},
    );

    try {
      final response = await http.get(uri, headers: _headers);
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as List<dynamic>? ?? [];
      final candidates = data.whereType<Map<String, dynamic>>().toList();
      if (candidates.isEmpty) return [];

      final scored = candidates.map((c) {
        final name = (c['name'] as String? ?? '').trim();
        return (candidate: c, nameScore: _nameScore(name, trimmed));
      }).toList()
        ..sort((a, b) => b.nameScore.compareTo(a.nameScore));

      var topCandidates = scored
          .where((s) => s.nameScore >= 0.05)
          .take(3)
          .toList();
      if (topCandidates.isEmpty) topCandidates.add(scored.first);

      var bestResult = (books: <Book>[], language: null as String?);
      double bestNameScore = 0.0;
      int bestScore = -1;

      for (final entry in topCandidates) {
        final asin = entry.candidate['asin'] as String?;
        if (asin == null || asin.isEmpty) continue;
        final result = await _fetchSeriesBooks(asin);
        if (result.books.isEmpty) continue;

        final totalScore = (entry.nameScore * 10000).round() + result.books.length;
        if (totalScore > bestScore) {
          bestScore = totalScore;
          bestResult = result;
          bestNameScore = entry.nameScore;
        }
      }

      if (bestNameScore < 0.1 || bestResult.books.isEmpty) return [];

      final author = _authorFrom(bestResult.books);
      if (author != null && author.isNotEmpty) {
        final extra = await _fetchAuthorBooks(
          author,
          bestResult.books,
          allowedLanguage: bestResult.language,
        );
        return _mergeAndSortSeriesBooks(bestResult.books, extra);
      }

      return _sortSeriesBooks(bestResult.books);
    } catch (_) {
      return [];
    }
  }

  double _nameScore(String seriesName, String query) {
    final sWords = meaningfulWords(seriesName);
    final qWords = meaningfulWords(query);
    if (sWords.isEmpty || qWords.isEmpty) return 0.0;

    if (sWords.length == qWords.length &&
        sWords.containsAll(qWords) &&
        qWords.containsAll(sWords)) {
      return 1.0;
    }

    final intersection = sWords.intersection(qWords).length;
    final union = sWords.union(qWords).length;
    return union == 0 ? 0.0 : intersection / union;
  }

  static final Set<String> _stopWords = {
    'the', 'a', 'an', 'and', 'or', 'of', 'in', 'on', 'at', 'to', 'for', 'with',
    'by', 'from', 'as', 'is', 'it', 'this', 'that', 'de', 'la', 'el', 'en',
    'die', 'der', 'und', 'das', 'les', 'une', 'et', 'le', 'series', 'trilogy',
    'saga', 'novel', 'story', 'stories', 'chronicles', 'volume', 'vol',
  };

  /// Exposed so callers can compare meaningful query words with the same rules.
  static Set<String> meaningfulWords(String text) {
    final normalized = normalizeForSearch(text);
    return RegExp(r"[\p{L}0-9']+", unicode: true)
        .allMatches(normalized)
        .map((m) => m.group(0)!)
        .where((w) => w.length > 2 && !_stopWords.contains(w))
        .toSet();
  }

  /// Exposed so callers can match umlaut/ASCII variants with the same rules.
  static String normalizeForSearch(String text) => _normalizeUmlauts(text.toLowerCase());

  static String _normalizeUmlauts(String text) {
    return text
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
        .replaceAll('ì', 'i');
  }

  String? _authorFrom(List<Book> books) {
    for (final book in books) {
      if (book.author != null && book.author!.isNotEmpty) return book.author!;
    }
    return null;
  }

  Future<({List<Book> books, String? language})> _fetchSeriesBooks(String asin) async {
    final uri = Uri.parse('$_base/series/$asin/books');

    try {
      final response = await http.get(uri, headers: _headers);
      if (response.statusCode != 200) return (books: <Book>[], language: null);

      final data = jsonDecode(response.body) as List<dynamic>? ?? [];
      final seen = <String>{};
      final books = <Book>[];
      final languageCounts = <String, int>{};

      for (final raw in data) {
        if (raw is! Map<String, dynamic>) continue;

        final title = (raw['title'] as String? ?? '').trim();
        final subtitle = (raw['subtitle'] as String? ?? '').trim();

        if (_isExcluded(title, subtitle)) continue;

        final posStr = _extractPositionString(raw, asin);
        if (posStr == null || posStr.contains('.')) continue;

        final book = _mapToBook(raw, seriesAsin: asin, posStr: posStr);
        final key = '${book.author ?? ''}|${book.orderIndex}';
        if (seen.contains(key)) continue;
        seen.add(key);
        books.add(book);

        final lang = (raw['language'] as String? ?? '').toLowerCase();
        if (lang.isNotEmpty) {
          languageCounts[lang] = (languageCounts[lang] ?? 0) + 1;
        }
      }

      books.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

      String? dominantLanguage;
      if (languageCounts.isNotEmpty) {
        dominantLanguage = languageCounts.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;
      }

      return (books: books, language: dominantLanguage);
    } catch (_) {
      return (books: <Book>[], language: null);
    }
  }

  Future<List<Book>> _fetchAuthorBooks(
    String authorName,
    List<Book> existingBooks, {
    String? allowedLanguage,
  }) async {
    final uri = Uri.parse('$_base/author/books').replace(
      queryParameters: {'name': authorName},
    );

    try {
      final response = await http.get(uri, headers: _headers);
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as List<dynamic>? ?? [];
      final existingTitles = existingBooks
          .where((b) => b.title.isNotEmpty)
          .map((b) => b.title.toLowerCase())
          .toSet();
      final referenceTitles = existingBooks
          .where((b) => b.title.isNotEmpty)
          .map((b) => b.title.toLowerCase())
          .toList();
      if (referenceTitles.isEmpty) return [];

      final books = <Book>[];
      final seen = <String>{...existingTitles};

      for (final raw in data) {
        if (raw is! Map<String, dynamic>) continue;

        final title = (raw['title'] as String? ?? '').trim();
        if (title.isEmpty) continue;

        final lang = (raw['language'] as String? ?? '').toLowerCase();
        if (allowedLanguage != null && allowedLanguage.isNotEmpty && lang != allowedLanguage) continue;

        final genres = (raw['genres'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map((g) => (g['name'] as String? ?? '').toLowerCase())
                .toList() ??
            [];
        if (genres.any(_isAdultThrillerGenre)) continue;

        final subtitle = (raw['subtitle'] as String? ?? '').trim();
        if (_isExcluded(title, subtitle)) continue;

        final text = '${raw['summary'] ?? ''} ${raw['description'] ?? ''} ${raw['subtitle'] ?? ''}'
            .toLowerCase();
        if (!referenceTitles.any((t) => text.contains(t))) continue;

        final book = _mapToBook(raw, seriesAsin: '', posStr: null);
        if (book.author == null || book.author!.isEmpty) continue;

        final key = book.title.toLowerCase();
        if (seen.contains(key)) continue;
        seen.add(key);
        books.add(book);
      }

      return _sortSeriesBooks(books);
    } catch (_) {
      return [];
    }
  }

  bool _isAdultThrillerGenre(String genre) {
    final g = genre.toLowerCase();
    return g.contains('thriller') ||
        g.contains('suspense') ||
        g.contains('mystery') ||
        g.contains('crime') ||
        g.contains('police');
  }

  bool _isExcluded(String title, String subtitle) {
    return _exclude.hasMatch('$title $subtitle'.toLowerCase());
  }

  String? _extractPositionString(Map<String, dynamic> raw, String seriesAsin) {
    final seriesList = raw['series'] as List<dynamic>?;
    if (seriesList != null) {
      for (final s in seriesList) {
        if (s is Map<String, dynamic> && s['asin'] == seriesAsin) {
          return (s['position'] as String?)?.trim();
        }
      }
    }

    final subtitle = (raw['subtitle'] as String? ?? '').toLowerCase();
    final match = RegExp(
      r'\bbook\s+(\d+(?:\.\d+)?)\b',
      caseSensitive: false,
    ).firstMatch(subtitle);
    return match?.group(1);
  }

  List<Book> _mergeAndSortSeriesBooks(List<Book> base, List<Book> extra) {
    final seen = <String>{};
    final merged = <Book>[];
    for (final book in [...base, ...extra]) {
      final key = '${book.title.toLowerCase()}|${(book.author ?? '').toLowerCase()}';
      if (seen.contains(key)) continue;
      seen.add(key);
      merged.add(book);
    }
    return _sortSeriesBooks(merged);
  }

  List<Book> _sortSeriesBooks(List<Book> books) {
    books.sort((a, b) {
      final aIndex = a.orderIndex == 0 ? 10000 : a.orderIndex;
      final bIndex = b.orderIndex == 0 ? 10000 : b.orderIndex;
      var cmp = aIndex.compareTo(bIndex);
      if (cmp != 0) return cmp;
      final ay = a.publishYear;
      final by = b.publishYear;
      if (ay != null && by != null) cmp = ay.compareTo(by);
      if (cmp != 0) return cmp;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return books;
  }

  Book _mapToBook(
    Map<String, dynamic> raw, {
    required String seriesAsin,
    String? posStr,
  }) {
    final title = (raw['title'] as String? ?? '').trim();

    final authorsRaw = raw['authors'] as List<dynamic>?;
    String? author;
    if (authorsRaw != null && authorsRaw.isNotEmpty) {
      final first = authorsRaw.first;
      if (first is Map<String, dynamic>) {
        author = (first['name'] as String?)?.trim();
      }
    }

    final imageUrl = raw['imageUrl'] as String?;
    final isbn = raw['isbn'] as String?;

    int? publishYear;
    final releaseDate = raw['releaseDate'] as String?;
    if (releaseDate != null && releaseDate.isNotEmpty) {
      final dt = DateTime.tryParse(releaseDate);
      if (dt != null) publishYear = dt.year;
    }

    var orderIndex = 0;
    if (posStr != null && posStr.isNotEmpty) {
      final pos = double.tryParse(posStr);
      if (pos != null) orderIndex = pos.floor();
    } else {
      final subtitle = (raw['subtitle'] as String? ?? '').toLowerCase();
      final match = RegExp(
        r'\bbook\s+(\d+)\b',
        caseSensitive: false,
      ).firstMatch(subtitle);
      if (match != null) {
        final parsed = int.tryParse(match.group(1)!);
        if (parsed != null) orderIndex = parsed;
      }
    }

    return Book(
      title: title,
      author: author,
      coverUrl: imageUrl,
      isbn: isbn,
      publishYear: publishYear,
      orderIndex: orderIndex,
    );
  }
}
