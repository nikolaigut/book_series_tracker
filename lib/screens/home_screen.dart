import 'package:flutter/material.dart';

import '../models/book.dart';
import '../models/series.dart';
import '../services/database_service.dart';
import 'search_screen.dart';
import 'series_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService _db = DatabaseService();
  List<ReadingSeries> _series = [];
  Map<int, List<Book>> _booksBySeries = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final series = await _db.getSeries();
    final Map<int, List<Book>> books = {};
    for (final s in series) {
      if (s.id != null) {
        books[s.id!] = await _db.getBooksForSeries(s.id!);
      }
    }
    setState(() {
      _series = series;
      _booksBySeries = books;
      _loading = false;
    });
  }

  void _navigateToSearch() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SearchScreen()))
        .then((_) => _loadData());
  }

  void _navigateToSeries(ReadingSeries series) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => SeriesScreen(series: series)))
        .then((_) => _loadData());
  }

  String _progressText(ReadingSeries series) {
    final books = _booksBySeries[series.id] ?? [];
    if (books.isEmpty) return 'Noch keine Bücher';
    final read = books.where((b) => b.read).length;
    return '$read / ${books.length} gelesen';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meine Leselisten'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _series.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text(
                      'Noch keine Reihen vorhanden.\nSuche ein Buch und füge es einer neuen Reihe hinzu.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _series.length,
                  itemBuilder: (context, index) {
                    final series = _series[index];
                    final books = _booksBySeries[series.id] ?? [];
                    final total = books.length;
                    final read = books.where((b) => b.read).length;
                    final progress = total == 0 ? 0.0 : read / total;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: Text(series.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (series.author != null && series.author!.isNotEmpty)
                              Text(series.author!),
                            Text(_progressText(series)),
                            LinearProgressIndicator(value: progress),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _navigateToSeries(series),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToSearch,
        tooltip: 'Buch suchen',
        child: const Icon(Icons.search),
      ),
    );
  }
}
