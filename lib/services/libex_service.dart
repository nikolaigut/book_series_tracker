import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/book.dart';

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
    r'(?:\s|$|[,;:!.)\]])',
    caseSensitive: false,
  );

  Future<List<Book>> searchSeriesBooks(String seriesName) async {
    final trimmed = seriesName.trim();
    if (trimmed.isEmpty) return [];

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

      List<Book> bestBooks = [];
      double bestNameScore = 0.0;
      int bestScore = -1;

      for (final entry in topCandidates) {
        final asin = entry.candidate['asin'] as String?;
        if (asin == null || asin.isEmpty) continue;
        final books = await _fetchSeriesBooks(asin);
        if (books.isEmpty) continue;

        final totalScore = (entry.nameScore * 10000).round() + books.length;
        if (totalScore > bestScore) {
          bestScore = totalScore;
          bestBooks = books;
          bestNameScore = entry.nameScore;
        }
      }

      if (bestNameScore < 0.1 || bestBooks.isEmpty) return [];
      return bestBooks;
    } catch (_) {
      return [];
    }
  }

  double _nameScore(String seriesName, String query) {
    final sWords = _meaningfulWords(seriesName);
    final qWords = _meaningfulWords(query);
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

  Set<String> _meaningfulWords(String text) {
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

  Future<List<Book>> _fetchSeriesBooks(String asin) async {
    final uri = Uri.parse('$_base/series/$asin/books');

    try {
      final response = await http.get(uri, headers: _headers);
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as List<dynamic>? ?? [];
      final seen = <String>{};
      final books = <Book>[];

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
      }

      books.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      return books;
    } catch (_) {
      return [];
    }
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
