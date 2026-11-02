import 'package:flutter/material.dart';

import 'features/notes/notes_page.dart';

void main() {
  runApp(const BasicApp());
}

/// Root widget for the basic FlutterGuard example.
class BasicApp extends StatelessWidget {
  /// Creates the material application.
  const BasicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(title: 'Basic App', home: NotesPage());
  }
}
