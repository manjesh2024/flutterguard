import 'dart:io';

import 'package:flutterguard_audit/flutterguard_audit.dart';

Future<void> main(List<String> args) async {
  final code = await FlutterGuardCli().run(args);
  exit(code);
}
