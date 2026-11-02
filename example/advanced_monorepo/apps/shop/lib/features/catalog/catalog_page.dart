import 'package:flutter/material.dart';
import 'package:shared_ui/shared_ui.dart';

/// Feature page that uses the shared package.
class CatalogPage extends StatelessWidget {
  /// Creates the catalog page.
  const CatalogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: SharedBadge(label: 'Shop')),
    );
  }
}
