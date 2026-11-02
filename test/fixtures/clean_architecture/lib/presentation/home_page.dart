import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../data/user_repository.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  int quote(int value) {
    if (value > 1 &&
        value > 2 &&
        value > 3 &&
        value > 4 &&
        value > 5 &&
        value > 6 &&
        value > 7 &&
        value > 8 &&
        value > 9 &&
        value > 10 &&
        value > 11 &&
        value > 12) {
      return value;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final repository = UserRepository();
    rawQuery();
    return Text(repository.load());
  }
}

void rawQuery() {}
