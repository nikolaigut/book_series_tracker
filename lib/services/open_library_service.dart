import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/book.dart';

enum SearchType { title, author, series, any }

class OpenLibraryService {
  static const String _baseSearchUrl = 'https://openlibrary.org/search.json';
  static const String _coverUrl = 'https://covers.openlibrary.org/b/id';

  Future<List<Book>> search(String query, {SearchType type = SearchType.any, int limit = 20}) async {
    if (query.trim().isEmpty) return [];

    if (type == SearchType.series) {
      return searchSeriesBooks(query, limit: limit);
    }

    final q = _buildQuery(query, type);
    return _fetchSearch(q, limit: limit);
  }

  Future<List<Book>> _fetchSearch(String q, {int limit = 20}) async {
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
      case SearchType.series:
        return 'series:"$escaped"';
      case SearchType.any:
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
    int limit = 100,
  }) async {
    final trimmed = seriesName.trim();
    if (trimmed.isEmpty) return [];

    final primary = await _fetchSearch('series:"$trimmed"', limit: 50);
    final allowedAuthors = _topAuthorsFrom(primary, top: 5);

    final allBooks = <Book>[...primary];
    final seenKeys = <String?>{...primary.map((b) => b.openLibraryKey)};

    for (final authorName in allowedAuthors) {
      final escaped = authorName.replaceAll('"', '\\"');
      final q = 'author:"$escaped" "$trimmed"';
      final results = await _fetchSearch(q, limit: 50);
      for (final book in results) {
        if (book.openLibraryKey == null || seenKeys.contains(book.openLibraryKey)) continue;
        seenKeys.add(book.openLibraryKey);
        allBooks.add(book);
      }
    }

    if (allBooks.length < 10) {
      final broad = await _fetchSearch('"$trimmed"', limit: 100);
      for (final book in broad) {
        if (book.openLibraryKey == null || seenKeys.contains(book.openLibraryKey)) continue;
        seenKeys.add(book.openLibraryKey);
        allBooks.add(book);
      }
    }

    final requiredPrefix = _derivePrefix(primary, seriesName: trimmed);

    return filterSeriesCandidates(
      allBooks,
      seriesName: seriesName,
      allowedAuthors: allowedAuthors,
      requiredPrefix: requiredPrefix,
    );
  }

  Set<String> _topAuthorsFrom(List<Book> books, {int top = 5}) {
    final counts = <String, int>{};
    for (final book in books) {
      if (book.author == null || book.author!.isEmpty) continue;
      for (final name in book.author!.split(',').map((s) => s.trim())) {
        if (name.isEmpty) continue;
        final key = name.toLowerCase();
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.length <= 8) {
      return sorted.map((e) => e.key).toSet();
    }
    final threshold = (sorted.first.value / 2).ceil();
    final frequent = sorted.where((e) => e.value >= threshold).take(top).map((e) => e.key).toSet();
    return frequent.isNotEmpty ? frequent : sorted.take(top).map((e) => e.key).toSet();
  }

  String? _derivePrefix(List<Book> primary, {required String seriesName}) {
    final seriesLower = seriesName.toLowerCase();
    final titles = primary
        .where((b) => b.title.toLowerCase().startsWith(seriesLower))
        .map((b) => b.title)
        .toList();
    if (titles.length < 2) return null;

    var prefix = titles.first.toLowerCase();
    for (final t in titles.skip(1)) {
      while (!t.toLowerCase().startsWith(prefix)) {
        prefix = prefix.substring(0, prefix.length - 1);
        if (prefix.isEmpty) break;
      }
      if (prefix.isEmpty) break;
    }
    prefix = prefix.trim();
    if (prefix.length >= seriesLower.length && prefix.startsWith(seriesLower)) {
      return prefix;
    }
    return null;
  }

  List<Book> filterSeriesCandidates(
    List<Book> books, {
    String? seriesName,
    Set<String>? allowedAuthors,
    String? requiredPrefix,
  }) {
    final seen = <String>{};
    var result = <Book>[];
    final exclude = RegExp(
      r'\(series\)|\bseries\b|\b(box set|boxed set|collection|pack|set|house|history of|unofficial|critical perspectives|guide|map of|beyond|political issues|prebound|untitled|recap|season \d|complete novels|two complete|three complete|explosive titles|coloring book|workbook|journal|almanac|pop|carnet|agenda|vocabulary|companion|sparknotes|info|display|postcard|movie book|cut[-\s]out|pop[-\s]up|pocket potters|magical year|afrikaans)\b|3[-–]d|\d+[-–]\d+|\d+/\d+|\s/\s',
      caseSensitive: false,
    );

    for (final book in books) {
      if (book.title.isEmpty) continue;
      if (!_isValidTitle(book.title)) continue;
      final normalized = _coreTitle(book.title, seriesName: seriesName, allowedAuthors: allowedAuthors);
      if (seen.contains(normalized)) continue;
      if (exclude.hasMatch(book.title)) continue;
      seen.add(normalized);
      result.add(book);
    }

    if (requiredPrefix != null && requiredPrefix.isNotEmpty) {
      final prefixLower = requiredPrefix.toLowerCase();
      result = result.where((book) {
        if (!book.title.toLowerCase().startsWith(prefixLower)) return false;
        if (allowedAuthors != null && allowedAuthors.isNotEmpty && book.author != null && book.author!.isNotEmpty) {
          final authorLower = book.author!.toLowerCase();
          return allowedAuthors.any((a) => authorLower.contains(a));
        }
        return true;
      }).toList();
    } else if (allowedAuthors != null && allowedAuthors.isNotEmpty) {
      result = result.where((book) {
        if (book.author == null || book.author!.isEmpty) return false;
        final authorLower = book.author!.toLowerCase();
        return allowedAuthors.any((a) => authorLower.contains(a));
      }).toList();
    } else if (seriesName != null && seriesName.trim().isNotEmpty) {
      final seriesLower = seriesName.toLowerCase();
      result = result.where((book) => book.title.toLowerCase().contains(seriesLower)).toList();
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

  String _coreTitle(String title, {String? seriesName, Set<String>? allowedAuthors}) {
    var t = title.toLowerCase()
      .replaceAll(RegExp(r'\s*\([^)]*\)'), '')
      .replaceAll(RegExp(r':.*$'), '')
      .replaceAll("'s", '')
      .replaceAll(RegExp(r'[^\w\s]'), '')
      .trim();

    for (final variant in _usSpellingVariants.entries) {
      t = t.replaceAll(variant.key, variant.value);
    }

    if (seriesName != null && seriesName.isNotEmpty) {
      final prefix = seriesName.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();
      t = t.replaceAll(RegExp('^$prefix\\s*'), '');
    }

    if (allowedAuthors != null) {
      for (final author in allowedAuthors) {
        final normalized = author.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();
        if (normalized.isEmpty) continue;
        final escaped = normalized.replaceAll(RegExp(r'\s+'), r'[\W_]*');
        final pattern = RegExp('^[\\W_]*$escaped[\\W_]*s?[\\W_]*');
        t = t.replaceFirst(pattern, '').trim();
      }
    }

    return t;
  }

  bool _isValidTitle(String title) {
    if (title.trim().isEmpty) return false;
    return !RegExp(r'[\x00-\x1F\x7F]').hasMatch(title);
  }

  Map<String, String> get _usSpellingVariants => const {
    'honour': 'honor',
    'honours': 'honors',
    'colour': 'color',
    'colours': 'colors',
    'centre': 'center',
    'favour': 'favor',
    'favours': 'favors',
    'neighbour': 'neighbor',
    'neighbours': 'neighbors',
    'defence': 'defense',
    'defences': 'defenses',
    'offence': 'offense',
    'offences': 'offenses',
  };

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
