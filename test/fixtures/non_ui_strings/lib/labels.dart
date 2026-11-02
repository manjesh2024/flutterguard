import 'package:flutter/material.dart';

class Labels extends StatelessWidget {
  const Labels({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [Text('Sign in'), Text('Debug session started')],
    );
  }
}
