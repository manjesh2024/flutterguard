import 'package:flutter/material.dart';

import 'features/catalog/catalog_page.dart';

void main() {
  runApp(const ShopApp());
}

/// Shop application entry widget.
class ShopApp extends StatelessWidget {
  /// Creates the shop application.
  const ShopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: CatalogPage());
  }
}
