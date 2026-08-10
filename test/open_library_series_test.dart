import 'package:flutter_test/flutter_test.dart';
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
}
