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

  Future<void> _addToSeries(Book book) async {
    final series = await _db.getSeries();
    if (!mounted) return;
    final result = await showDialog<ReadingSeries?>(
      context: context,
      builder: (_) => AddToSeriesDialog(book: book, existingSeries: series),
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
                    onTap: () => _addToSeries(book),
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
