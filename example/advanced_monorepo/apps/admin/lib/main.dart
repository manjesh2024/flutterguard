import 'package:flutter/material.dart';
import 'package:shared_ui/shared_ui.dart';

void main() {
  runApp(const AdminApp());
}

/// Admin application entry widget.
class AdminApp extends StatelessWidget {
  /// Creates the admin application.
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(child: SharedBadge(label: 'Admin')),
      ),
    );
  }
}
