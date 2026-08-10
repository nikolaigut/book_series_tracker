import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/book.dart';

enum SearchType { title, author, any }

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

    return docs.whereType<Map<String, dynamic>>().map(_mapToBook).toList();
  }

  String _buildQuery(String query, SearchType type) {
    final escaped = query.trim();
    switch (type) {
      case SearchType.title:
        return 'title:"$escaped"';
      case SearchType.author:
        return 'author:"$escaped"';
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
    int limit = 50,
  }) async {
    if (seriesName.trim().isEmpty) return [];

    final parts = ['series:"${seriesName.trim()}"'];
    if (author != null && author.trim().isNotEmpty) {
      parts.add('author_name:"${author.trim()}"');
    }
    final q = parts.join(' ');

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

    final seen = <String>{};
    final books = <Book>[];
    final exclude = RegExp(
      r'\(series\)|\b(box set|collection|pack|house|history of|unofficial|critical perspectives|guide|map of|beyond|political issues)\b|\d+[-–]\d+|\s/\s',
      caseSensitive: false,
    );

    for (final doc in docs.whereType<Map<String, dynamic>>()) {
      final book = _mapToBook(doc);
      if (book.title.isEmpty) continue;
      final normalized = book.title.toLowerCase().trim();
      if (seen.contains(normalized)) continue;
      if (exclude.hasMatch(book.title)) continue;
      if (author != null && author.isNotEmpty && !_authorMatches(author, doc['author_name'])) continue;
      seen.add(normalized);
      books.add(book);
    }

    books.sort((a, b) {
      final ay = a.publishYear;
      final by = b.publishYear;
      if (ay == null && by == null) return 0;
      if (ay == null) return 1;
      if (by == null) return -1;
      return ay.compareTo(by);
    });
    return books;
  }

  bool _authorMatches(String author, dynamic authors) {
    if (authors is! List) return false;
    final names = authors.whereType<String>().toList();
    if (names.isEmpty) return false;
    final search = author.toLowerCase().replaceAll(RegExp(r'[\.\s]'), '');
    return names.any((name) => name.toLowerCase().replaceAll(RegExp(r'[\.\s]'), '').contains(search));
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
