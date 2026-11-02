import 'package:flutter/material.dart';

/// Small label shared by the shop and admin applications.
class SharedBadge extends StatelessWidget {
  /// Creates a badge whose visible text is [label].
  const SharedBadge({required this.label, super.key});

  /// Short label. Callers pass a single word.
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label);
  }
}
