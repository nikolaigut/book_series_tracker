import 'package:flutter_test/flutter_test.dart';
import 'package:book_series_tracker/services/libex_service.dart';

void main() {
  test('Powerless series via Libex', () async {
    final service = LibexService();
    final results = await service.searchSeriesBooks('Powerless');
    expect(results.length, greaterThanOrEqualTo(3));
    final titles = results.map((b) => b.title.toLowerCase()).toList();
    expect(titles, contains('powerless'));
    expect(titles, contains('reckless'));
  });
}
