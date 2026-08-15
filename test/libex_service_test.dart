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
  });

  test('Libex Bücher der Macht by Liza Grimm', () async {
    final service = LibexService();
    final results = await service.searchSeriesBooks('Bücher der Macht');
    expect(results.length, greaterThanOrEqualTo(3));
    final titles = results.map((b) => b.title.toLowerCase()).toList();
    expect(titles, contains('eislotus - wasser findet seinen weg'));
    expect(titles, contains('feuerlilie - asche spendet leben'));
  });

  test('Libex umlaut ASCII fallback matches Bücher der Macht', () async {
    final service = LibexService();
    final results = await service.searchSeriesBooks('Buecher der Macht');
    expect(results.isNotEmpty, true);
    final authors = results.map((b) => b.author?.toLowerCase() ?? '').toSet();
    expect(authors, contains('liza grimm'));
  });
}
