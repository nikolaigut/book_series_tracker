import 'package:flutter_test/flutter_test.dart';
import 'package:book_series_tracker/services/libex_service.dart';
import 'package:book_series_tracker/services/open_library_service.dart';

void main() {
  test('Libex finds complete Girl, Goddess, Queen series', () async {
    final service = LibexService();
    final results = await service.searchSeriesBooks('Girl, Goddess, Queen');
    expect(results.length, greaterThanOrEqualTo(4));
    final titles = results.map((b) => b.title.toLowerCase()).toSet();
    expect(titles, contains('girl, goddess, queen'));
    expect(titles, contains('the end crowns all'));
    expect(titles, contains('a beautiful evil'));
    expect(titles, contains('this divine revelry'));
  });

  test('OpenLibrary series search is missing the sequel', () async {
    final service = OpenLibraryService();
    final results = await service.search(
      'Girl, Goddess, Queen',
      type: SearchType.series,
    );
    expect(results.length, lessThan(2));
  });
}
