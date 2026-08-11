import 'package:flutter_test/flutter_test.dart';
import 'package:book_series_tracker/services/libex_service.dart';

void main() {
  test('Libex Harry Potter series', () async {
    final service = LibexService();
    final results = await service.searchSeriesBooks('Harry Potter');
    expect(results.length, greaterThanOrEqualTo(7));
  });

  test('Libex Reign of Remnants / The Wind Weaver', () async {
    final service = LibexService();
    final results = await service.searchSeriesBooks('The Wind Weaver');
    expect(results.isNotEmpty, true);
    for (final b in results) {
      print('${b.orderIndex + 1}. ${b.title} - ${b.author}');
    }
  });
}
