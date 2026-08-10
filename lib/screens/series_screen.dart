import 'package:flutter/material.dart';

import '../models/book.dart';
import '../models/series.dart';
import '../services/database_service.dart';
import 'book_detail_screen.dart';

class SeriesScreen extends StatefulWidget {
  final ReadingSeries series;

  const SeriesScreen({super.key, required this.series});

  @override
  State<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends State<SeriesScreen> {
  final DatabaseService _db = DatabaseService();
  List<Book> _books = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    final books = await _db.getBooksForSeries(widget.series.id!);
    setState(() {
      _books = books;
      _loading = false;
    });
  }

  Future<void> _toggleRead(Book book) async {
    final updated = book.copyWith(read: !book.read);
    await _db.updateBook(updated);
    _loadBooks();
  }

  Future<void> _deleteBook(Book book) async {
    if (book.id == null) return;
    await _db.deleteBook(book.id!);
    _loadBooks();
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = _books.removeAt(oldIndex);
    _books.insert(newIndex, moved);

    for (int i = 0; i < _books.length; i++) {
      final book = _books[i].copyWith(orderIndex: i);
      await _db.updateBook(book);
    }
    _loadBooks();
  }

  @override
  Widget build(BuildContext context) {
    final readCount = _books.where((b) => b.read).length;
    final progress = _books.isEmpty ? 0.0 : readCount / _books.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.series.name),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text('$readCount / ${_books.length} gelesen'),
                      LinearProgressIndicator(value: progress, minHeight: 8),
                    ],
                  ),
                ),
                Expanded(
                  child: _books.isEmpty
                      ? const Center(child: Text('Noch keine Bücher in dieser Reihe.'))
                      : ReorderableListView.builder(
                          itemCount: _books.length,
                          onReorder: _reorder,
                          itemBuilder: (context, index) {
                            final book = _books[index];
                            return Card(
                              key: ValueKey(book.id),
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              child: ListTile(
                                leading: Checkbox(
                                  value: book.read,
                                  onChanged: (_) => _toggleRead(book),
                                ),
                                title: Text(
                                  book.title,
                                  style: TextStyle(
                                    decoration: book.read ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                                subtitle: book.author != null ? Text(book.author!) : null,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.info_outline),
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => BookDetailScreen(book: book),
                                          ),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () => _deleteBook(book),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
