import 'package:shared_preferences/shared_preferences.dart';

Future<void> save(SharedPreferences prefs) async {
  await prefs.setString('auth_token', 'stored-token-value');
}
