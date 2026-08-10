import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/book.dart';

enum SearchType { title, author, series, any }

class OpenLibraryService {
  static const String _baseSearchUrl = 'https://openlibrary.org/search.json';
  static const String _coverUrl = 'https://covers.openlibrary.org/b/id';

  Future<List<Book>> search(String query, {SearchType type = SearchType.any, int limit = 20}) async {
    if (query.trim().isEmpty) return [];

    final q = _buildQuery(query, type);
    final uri = Uri.parse(_baseSearchUrl).replace(
      queryParameters: {
        'q': q,
        'limit': limit.toString(),
        'fields': 'key,title,author_name,first_publish_year,cover_i,isbn',
      },
    );

    final response = await http.get(uri, headers: {'Accept': 'application/json'});
    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final docs = data['docs'] as List<dynamic>? ?? [];

    final books = docs.whereType<Map<String, dynamic>>().map(_mapToBook).toList();
    if (type == SearchType.series) {
      return filterSeriesCandidates(books);
    }
    return books;
  }

  String _buildQuery(String query, SearchType type) {
    final escaped = query.trim();
    switch (type) {
      case SearchType.title:
        return 'title:"$escaped"';
      case SearchType.author:
        return 'author:"$escaped"';
      case SearchType.series:
        return 'series:"$escaped"';
      case SearchType.any:
      default:
        return escaped;
    }
  }

  Future<Map<String, dynamic>?> fetchWork(String key) async {
    if (key.isEmpty) return null;
    final uri = Uri.parse('https://openlibrary.org$key.json');
    final response = await http.get(uri, headers: {'Accept': 'application/json'});
    if (response.statusCode != 200) return null;
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<String?> fetchSeriesName(String seriesKey) async {
    if (seriesKey.isEmpty) return null;
    final uri = Uri.parse('https://openlibrary.org$seriesKey.json');
    final response = await http.get(uri, headers: {'Accept': 'application/json'});
    if (response.statusCode != 200) return null;
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['name'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<List<Book>> searchSeriesBooks(
    String seriesName, {
    String? author,
    int limit = 20,
  }) async {
    if (seriesName.trim().isEmpty) return [];

    final q = 'series:"${seriesName.trim()}"';
    final uri = Uri.parse(_baseSearchUrl).replace(
      queryParameters: {
        'q': q,
        'limit': limit.toString(),
        'fields': 'key,title,author_name,first_publish_year,cover_i,isbn',
      },
    );

    final response = await http.get(uri, headers: {'Accept': 'application/json'});
    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final docs = data['docs'] as List<dynamic>? ?? [];

    final books = docs.whereType<Map<String, dynamic>>().map(_mapToBook).toList();
    return filterSeriesCandidates(books);
  }

  List<Book> filterSeriesCandidates(List<Book> books) {
    final seen = <String>{};
    var result = <Book>[];
    final exclude = RegExp(
      r'\(series\)|\bseries\b|\b(box set|boxed set|collection|pack|set|house|history of|unofficial|critical perspectives|guide|map of|beyond|political issues|prebound|untitled)\b|\d+[-–]\d+|\s/\s',
      caseSensitive: false,
    );

    for (final book in books) {
      if (book.title.isEmpty) continue;
      final normalized = _normalizeTitle(book.title);
      if (seen.contains(normalized)) continue;
      if (exclude.hasMatch(book.title)) continue;
      seen.add(normalized);
      result.add(book);
    }

    // If one author dominates, keep only books by that author to avoid
    // unrelated titles that are merely tagged with the same series.
    final authorCounts = <String, int>{};
    for (final book in result) {
      if (book.author != null && book.author!.isNotEmpty) {
        for (final name in book.author!.split(',').map((s) => s.trim())) {
          authorCounts[name] = (authorCounts[name] ?? 0) + 1;
        }
      }
    }
    String? topAuthor;
    var topCount = 0;
    authorCounts.forEach((name, count) {
      if (count > topCount) {
        topCount = count;
        topAuthor = name;
      }
    });
    if (topAuthor != null && topCount * 2 > result.length) {
      result = result
          .where((b) => b.author != null && b.author!.toLowerCase().contains(topAuthor!.toLowerCase()))
          .toList();
    }

    result.sort((a, b) {
      final ay = a.publishYear;
      final by = b.publishYear;
      if (ay == null && by == null) return 0;
      if (ay == null) return 1;
      if (by == null) return -1;
      return ay.compareTo(by);
    });
    return result;
  }

  String _normalizeTitle(String title) {
    return title
        .toLowerCase()
        .replaceAll(RegExp(r'\s*\([^)]*\)'), '')
        .replaceAll(RegExp(r':.*$'), '')
        .trim();
  }

  Book _mapToBook(Map<String, dynamic> doc) {
    final key = doc['key'] as String?;
    final title = doc['title'] as String? ?? 'Unbekannter Titel';
    final authors = doc['author_name'] as List<dynamic>?;
    final author = authors?.whereType<String>().join(', ');
    final year = doc['first_publish_year'] as int?;
    final coverId = doc['cover_i'] as int?;
    final isbns = doc['isbn'] as List<dynamic>?;
    final isbn = isbns?.whereType<String>().firstOrNull;

    return Book(
      title: title,
      author: author,
      openLibraryKey: key,
      isbn: isbn,
      coverUrl: coverId != null ? '$_coverUrl/$coverId-M.jpg' : null,
      publishYear: year,
    );
  }
}
