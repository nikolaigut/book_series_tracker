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
