import 'package:flutter/material.dart';

import '../models/book.dart';
import '../services/database_service.dart';
import '../services/onleihe_service.dart';

class BookDetailScreen extends StatefulWidget {
  final Book book;

  const BookDetailScreen({super.key, required this.book});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  final DatabaseService _db = DatabaseService();
  final OnleiheService _onleihe = OnleiheService();
  late Book _book;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
  }

  Future<void> _toggleRead() async {
    final updated = _book.copyWith(read: !_book.read);
    await _db.updateBook(updated);
    setState(() => _book = updated);
  }

  Future<void> _deleteBook() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Buch löschen'),
        content: Text('Soll "${_book.title}" gelöscht werden?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true || _book.id == null) return;
    await _db.deleteBook(_book.id!);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _openOnleihe() async {
    final ok = await _onleihe.searchAvailability(_book.title);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Onleihe konnte nicht geöffnet werden.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_book.title),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Buch löschen',
            onPressed: _deleteBook,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_book.coverUrl != null)
              Center(
                child: Image.network(
                  _book.coverUrl!,
                  height: 220,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.book, size: 120),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              _book.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (_book.author != null && _book.author!.isNotEmpty)
              Text('Autor: ${_book.author}', style: Theme.of(context).textTheme.titleMedium),
            if (_book.publishYear != null)
              Text('Erscheinungsjahr: ${_book.publishYear}'),
            if (_book.isbn != null && _book.isbn!.isNotEmpty)
              Text('ISBN: ${_book.isbn}'),
            const SizedBox(height: 24),
            Row(
              children: [
                Checkbox(
                  value: _book.read,
                  onChanged: (_) => _toggleRead(),
                ),
                Text(
                  _book.read ? 'Bereits gelesen' : 'Noch nicht gelesen',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openOnleihe,
                icon: const Icon(Icons.open_in_browser),
                label: const Text('Verfügbarkeit in Onleihe prüfen'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
