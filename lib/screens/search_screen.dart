import 'package:flutter/material.dart';

import '../models/book.dart';
import '../models/series.dart';
import '../services/database_service.dart';
import '../services/open_library_service.dart';
import '../widgets/add_to_series_dialog.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final OpenLibraryService _openLibrary = OpenLibraryService();
  final DatabaseService _db = DatabaseService();
  final TextEditingController _controller = TextEditingController();

  int _selectedFilter = 0; // 0 = title, 1 = author, 2 = any
  bool _loading = false;
  List<Book> _results = [];
  String? _error;

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _results = [];
    });

    try {
      final type = _selectedFilter == 0
          ? SearchType.title
          : _selectedFilter == 1
              ? SearchType.author
              : SearchType.any;
      final results = await _openLibrary.search(query, type: type);
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<ReadingSeries?> _chooseSeries({String? initialName, String? initialAuthor}) async {
    final series = await _db.getSeries();
    if (!mounted) return null;
    return showDialog<ReadingSeries?>(
      context: context,
      builder: (_) => AddToSeriesDialog(
        initialName: initialName,
        initialAuthor: initialAuthor,
        existingSeries: series,
      ),
    );
  }

  Future<void> _addBook(Book book) async {
    final result = await _chooseSeries(
      initialName: book.title,
      initialAuthor: book.author,
    );
    if (result == null) return;

    int? seriesId = result.id;
    seriesId ??= await _db.insertSeries(result);

    final order = (await _db.getBooksForSeries(seriesId)).length;
    await _db.insertBook(
      book.copyWith(
        seriesId: seriesId,
        orderIndex: order,
      ),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${book.title}" zur Reihe hinzugefügt')),
      );
    }
  }

  Future<void> _addBooks(List<Book> books, {String? initialName, String? initialAuthor}) async {
    if (books.isEmpty) return;

    final result = await _chooseSeries(
      initialName: initialName ?? books.first.title,
      initialAuthor: initialAuthor ?? books.first.author,
    );
    if (result == null) return;

    int? seriesId = result.id;
    seriesId ??= await _db.insertSeries(result);

    final existing = await _db.getBooksForSeries(seriesId);
    var order = existing.length;
    for (final book in books) {
      await _db.insertBook(
        book.copyWith(
          seriesId: seriesId,
          orderIndex: order,
        ),
      );
      order++;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${books.length} Bücher zur Reihe hinzugefügt')),
      );
    }
  }

  Future<String?> _detectSeriesName(Book book) async {
    final key = book.openLibraryKey;
    if (key == null || key.isEmpty) return null;

    final work = await _openLibrary.fetchWork(key);
    if (work == null) return null;

    final seriesList = work['series'] as List<dynamic>?;
    if (seriesList == null || seriesList.isEmpty) return null;

    final first = seriesList.first;
    if (first is String) return first;
    if (first is Map<String, dynamic>) {
      final name = first['name'] as String?;
      if (name != null && name.isNotEmpty) return name;

      final seriesMap = first['series'] as Map<String, dynamic>?;
      final seriesKey = seriesMap?['key'] as String?;
      if (seriesKey != null && seriesKey.isNotEmpty) {
        return _openLibrary.fetchSeriesName(seriesKey);
      }
    }
    return null;
  }

  Future<void> _onBookTapped(Book book) async {
    setState(() => _loading = true);
    String? seriesName;
    try {
      seriesName = await _detectSeriesName(book);
    } finally {
      setState(() => _loading = false);
    }

    if (!mounted) return;

    if (seriesName == null || seriesName.isEmpty) {
      await _addBook(book);
      return;
    }

    final choice = await showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reihe erkannt'),
        content: Text('"${book.title}" gehört zur Reihe "$seriesName". Was möchtest du hinzufügen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('single'),
            child: const Text('Nur dieses Buch'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('series'),
            child: const Text('Ganze Reihe'),
          ),
        ],
      ),
    );

    if (choice == null) return;

    if (choice == 'single') {
      await _addBook(book);
    } else {
      setState(() => _loading = true);
      List<Book> books = [];
      try {
        books = await _openLibrary.searchSeriesBooks(seriesName, author: book.author);
      } finally {
        setState(() => _loading = false);
      }

      if (!mounted) return;

      if (books.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Keine weiteren Bücher der Reihe gefunden')),
        );
        return;
      }

      await _addBooks(books, initialName: seriesName, initialAuthor: book.author);
    }
  }

  Future<void> _addAllToSeries() async {
    if (_results.isEmpty) return;

    final first = _results.first;
    await _addBooks(
      _results,
      initialName: _controller.text.trim(),
      initialAuthor: first.author,
    );
  }

  String _filterLabel(int index) {
    switch (index) {
      case 0:
        return 'Titel';
      case 1:
        return 'Autor';
      case 2:
        return 'Alles';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buch suchen'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add),
            tooltip: 'Alle zur Reihe hinzufügen',
            onPressed: _results.isEmpty ? null : _addAllToSeries,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Suchbegriff eingeben',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _search,
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ChoiceChip(
                  label: Text(_filterLabel(0)),
                  selected: _selectedFilter == 0,
                  onSelected: (_) => setState(() => _selectedFilter = 0),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(_filterLabel(1)),
                  selected: _selectedFilter == 1,
                  onSelected: (_) => setState(() => _selectedFilter = 1),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(_filterLabel(2)),
                  selected: _selectedFilter == 2,
                  onSelected: (_) => setState(() => _selectedFilter = 2),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading) const CircularProgressIndicator(),
            if (_error != null)
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final book = _results[index];
                  return ListTile(
                    leading: book.coverUrl != null
                        ? Image.network(
                            book.coverUrl!,
                            width: 50,
                            height: 70,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox(
                              width: 50,
                              height: 70,
                              child: Icon(Icons.book),
                            ),
                          )
                        : const SizedBox(
                            width: 50,
                            height: 70,
                            child: Icon(Icons.book),
                          ),
                    title: Text(book.title),
                    subtitle: Text(
                      [
                        if (book.author != null && book.author!.isNotEmpty) book.author!,
                        if (book.publishYear != null) '${book.publishYear}',
                      ].join(' · '),
                    ),
                    onTap: () => _onBookTapped(book),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
