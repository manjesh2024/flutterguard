import '../data/store.dart';

/// Presentation file that imports the data layer.
class HomePage {
  /// Reads the store and builds a user-facing literal.
  Text build() {
    Store().read();
    return const Text('Welcome back');
  }
}

/// Stand-in for a text widget so the sample does not need a resolved SDK.
class Text {
  /// Creates a text widget with [value].
  const Text(this.value);

  /// Literal captured by the hardcoded-string check.
  final String value;
}
