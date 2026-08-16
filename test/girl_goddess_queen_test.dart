import 'package:flutter_test/flutter_test.dart';
import 'package:book_series_tracker/services/libex_service.dart';
import 'package:book_series_tracker/services/open_library_service.dart';

void main() {
  test('Libex finds complete Girl, Goddess, Queen series', () async {
    final service = LibexService();
    final results = await service.searchSeriesBooks('Girl, Goddess, Queen');
    expect(results.length, 3);
    final titles = results.map((b) => b.title.toLowerCase()).toSet();
    expect(
      titles,
      contains('girl, goddess, queen: mein name ist persephone'),
    );
    expect(
      titles,
      contains('princess, prophet, saviour: kassandra, die prophetin, der keiner glaubt'),
    );
    expect(
      titles,
      contains('girl, lover, legend – die liebe der pandora'),
    );
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
