import 'package:flutter_test/flutter_test.dart';
import 'package:book_series_tracker/models/book.dart';
import 'package:book_series_tracker/services/open_library_service.dart';

void main() {
  test('search Jack Ryan series', () async {
    final service = OpenLibraryService();
    final results = await service.search('Jack Ryan', type: SearchType.series);
    expect(results.length, greaterThanOrEqualTo(20));
  });

  test('search Harry Potter series', () async {
    final service = OpenLibraryService();
    final results = await service.search('Harry Potter', type: SearchType.series);
    expect(results.isNotEmpty, true);
  });

  test('filterSeriesCandidates keeps German titles with umlauts', () {
    final service = OpenLibraryService();
    final books = [
      const Book(title: 'Bücher der Macht', author: 'Liza Grimm'),
    ];
    final results = service.filterSeriesCandidates(
      books,
      seriesName: 'Bücher der Macht',
    );
    expect(results.length, 1);
    expect(results.first.title, 'Bücher der Macht');
  });
}
