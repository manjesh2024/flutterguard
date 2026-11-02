/// Small glob matcher for project-relative POSIX paths.
///
/// Supported syntax is `*`, `?`, and `**`. Character classes and brace
/// expansion are rejected by configuration validation before they get here.
final class GlobMatcher {
  /// Compiles [pattern] into a full-string match.
  ///
  /// `*` matches inside one path segment, `?` matches one non-`/` character,
  /// and `**` matches across segments. `**/` may match an empty prefix.
  GlobMatcher(this.pattern) : _expression = RegExp(_compile(pattern));

  /// Pattern passed to the constructor, unchanged.
  final String pattern;
  final RegExp _expression;

  /// Whether [posixPath] matches [pattern] from start to end.
  ///
  /// Backslashes are treated as separators. A leading `./` or `/` is removed
  /// before matching.
  bool matches(String posixPath) {
    final normalized = posixPath
        .replaceAll('\\', '/')
        .replaceFirst(RegExp(r'^\./'), '')
        .replaceFirst(RegExp(r'^/'), '');
    return _expression.hasMatch(normalized);
  }

  /// Whether [pattern] contains `[`, `]`, `{`, or `}`.
  ///
  /// Those characters are outside the supported `*`, `?`, and `**` syntax.
  static bool hasUnsupportedSyntax(String pattern) {
    return pattern.contains('[') ||
        pattern.contains(']') ||
        pattern.contains('{') ||
        pattern.contains('}');
  }

  static String _compile(String pattern) {
    final buffer = StringBuffer('^');
    var index = 0;
    while (index < pattern.length) {
      final char = pattern[index];
      if (char == '*') {
        final isDouble =
            index + 1 < pattern.length && pattern[index + 1] == '*';
        if (isDouble) {
          final hasSlash =
              index + 2 < pattern.length && pattern[index + 2] == '/';
          if (hasSlash) {
            buffer.write('(?:.*/)?');
            index += 3;
            continue;
          }
          buffer.write('.*');
          index += 2;
          continue;
        }
        buffer.write('[^/]*');
        index += 1;
        continue;
      }
      if (char == '?') {
        buffer.write('[^/]');
        index += 1;
        continue;
      }
      if (r'.+()^$|\\'.contains(char)) {
        buffer.write('\\$char');
        index += 1;
        continue;
      }
      buffer.write(char);
      index += 1;
    }
    buffer.write(r'$');
    return buffer.toString();
  }
}

/// Whether any matcher in [matchers] matches [posixPath].
///
/// Returns false when [matchers] is empty. Stops at the first match.
bool anyGlobMatches(Iterable<GlobMatcher> matchers, String posixPath) {
  for (final matcher in matchers) {
    if (matcher.matches(posixPath)) {
      return true;
    }
  }
  return false;
}
