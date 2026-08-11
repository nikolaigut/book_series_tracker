import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/book.dart';

class LibexService {
  static const String _base = 'https://libex.lostcartographer.xyz';
  static const Map<String, String> _headers = {
    'User-Agent': 'book_series_tracker/1.0',
  };

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
      final candidates = data.whereType<Map<String, dynamic>>().take(10).toList();
      if (candidates.isEmpty) return [];

      final scored = <({int score, List<Book> books})>[];
      for (final candidate in candidates) {
        final asin = candidate['asin'] as String?;
        if (asin == null || asin.isEmpty) continue;
        final books = await _fetchSeriesBooks(asin);
        if (books.isEmpty) continue;
        final name = (candidate['name'] as String? ?? '').trim();
        final nameScore = _nameScore(name, trimmed);
        scored.add((score: nameScore * 1000 + books.length, books: books));
      }

      if (scored.isEmpty) return [];
      scored.sort((a, b) => b.score.compareTo(a.score));
      return scored.first.books;
    } catch (_) {
      return [];
    }
  }

  int _nameScore(String seriesName, String query) {
    final s = seriesName.toLowerCase();
    final q = query.toLowerCase();
    if (s == q) return 10;
    if (s.contains(q) || q.contains(s)) return 5;

    final qWords = q.split(RegExp(r'\s+')).where((w) => w.length > 2).toSet();
    final sWords = s.split(RegExp(r'\s+')).where((w) => w.length > 2).toSet();
    if (qWords.intersection(sWords).isNotEmpty) return 2;
    return 0;
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
        final book = _mapToBook(raw, seriesAsin: asin, fallbackIndex: books.length);
        final key = '${book.title}|${book.author ?? ''}|${book.orderIndex}';
        if (seen.contains(key)) continue;
        seen.add(key);
        books.add(book);
      }

      return books;
    } catch (_) {
      return [];
    }
  }

  Book _mapToBook(
    Map<String, dynamic> raw, {
    required String seriesAsin,
    required int fallbackIndex,
  }) {
    final title = (raw['title'] as String? ?? '').trim();
    final subtitle = (raw['subtitle'] as String? ?? '').trim();

    final fullTitle = subtitle.isNotEmpty && !title.toLowerCase().contains(subtitle.toLowerCase())
        ? '$title: $subtitle'
        : title;

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

    int? position;
    final seriesList = raw['series'] as List<dynamic>?;
    if (seriesList != null) {
      for (final s in seriesList) {
        if (s is Map<String, dynamic> && s['asin'] == seriesAsin) {
          final posStr = s['position'] as String?;
          if (posStr != null && posStr.isNotEmpty) {
            final pos = double.tryParse(posStr);
            if (pos != null) position = pos.floor();
          }
          break;
        }
      }
    }

    if (position == null) {
      final match = RegExp(r'\bbook\s+(\d+)\b', caseSensitive: false).firstMatch(subtitle);
      if (match != null) position = int.tryParse(match.group(1)!);
    }

    return Book(
      title: fullTitle,
      author: author,
      coverUrl: imageUrl,
      isbn: isbn,
      publishYear: publishYear,
      orderIndex: position ?? fallbackIndex,
    );
  }
}
