import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:book_series_tracker/main.dart';

void main() {
  testWidgets('App shows home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const BookSeriesTrackerApp());
    expect(find.text('Meine Leselisten'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
