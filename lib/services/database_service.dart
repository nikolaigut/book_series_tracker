import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

import '../models/book.dart';
import '../models/series.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  final _seriesStore = intMapStoreFactory.store('series');
  final _booksStore = intMapStoreFactory.store('books');

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final appDir = await getApplicationDocumentsDirectory();
    await appDir.create(recursive: true);
    final dbPath = join(appDir.path, 'book_series_tracker.db');
    return databaseFactoryIo.openDatabase(dbPath);
  }

  Map<String, dynamic> _withKey(int key, Map<String, dynamic> map) {
    return {...map, 'id': key};
  }

  Future<int> insertSeries(ReadingSeries series) async {
    final db = await database;
    final map = {...series.toMap()}..remove('id');
    final key = await _seriesStore.add(db, map);
    await _seriesStore.record(key).update(db, {'id': key});
    return key;
  }

  Future<int> updateSeries(ReadingSeries series) async {
    final db = await database;
    final key = series.id;
    if (key == null) return 0;
    final map = {...series.toMap()}..remove('id');
    await _seriesStore.record(key).update(db, map);
    return 1;
  }

  Future<int> deleteSeries(int id) async {
    final db = await database;
    await deleteBooksForSeries(id);
    await _seriesStore.record(id).delete(db);
    return 1;
  }

  Future<List<ReadingSeries>> getSeries() async {
    final db = await database;
    final snapshots = await _seriesStore.find(
      db,
      finder: Finder(sortOrders: [SortOrder('name')]),
    );
    return snapshots
        .map((s) => ReadingSeries.fromMap(_withKey(s.key, s.value)))
        .toList();
  }

  Future<ReadingSeries?> getSeriesById(int id) async {
    final db = await database;
    final snapshot = await _seriesStore.record(id).getSnapshot(db);
    if (snapshot == null) return null;
    return ReadingSeries.fromMap(_withKey(snapshot.key, snapshot.value));
  }

  Future<int> insertBook(Book book) async {
    final db = await database;
    final map = {...book.toMap()}..remove('id');
    final key = await _booksStore.add(db, map);
    await _booksStore.record(key).update(db, {'id': key});
    return key;
  }

  Future<int> updateBook(Book book) async {
    final db = await database;
    final key = book.id;
    if (key == null) return 0;
    final map = {...book.toMap()}..remove('id');
    await _booksStore.record(key).update(db, map);
    return 1;
  }

  Future<int> deleteBook(int id) async {
    final db = await database;
    await _booksStore.record(id).delete(db);
    return 1;
  }

  Future<int> deleteBooksForSeries(int seriesId) async {
    final db = await database;
    return _booksStore.delete(
      db,
      finder: Finder(filter: Filter.equals('seriesId', seriesId)),
    );
  }

  Future<List<Book>> getBooksForSeries(int seriesId) async {
    final db = await database;
    final snapshots = await _booksStore.find(
      db,
      finder: Finder(
        filter: Filter.equals('seriesId', seriesId),
        sortOrders: [SortOrder('orderIndex'), SortOrder('title')],
      ),
    );
    return snapshots
        .map((s) => Book.fromMap(_withKey(s.key, s.value)))
        .toList();
  }

  Future<Book?> getBookById(int id) async {
    final db = await database;
    final snapshot = await _booksStore.record(id).getSnapshot(db);
    if (snapshot == null) return null;
    return Book.fromMap(_withKey(snapshot.key, snapshot.value));
  }

  Future<void> setBookRead(int bookId, bool read) async {
    final db = await database;
    await _booksStore.record(bookId).update(db, {'read': read ? 1 : 0});
  }
}
