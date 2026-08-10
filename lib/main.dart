import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const BookSeriesTrackerApp());
}

class BookSeriesTrackerApp extends StatelessWidget {
  const BookSeriesTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Buch-Reihen Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
