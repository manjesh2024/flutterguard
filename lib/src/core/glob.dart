/// Small glob matcher for project-relative POSIX paths.
///
/// Supported syntax is `*`, `?`, and `**`. Character classes and brace
/// expansion are rejected by configuration validation before they get here.
final class GlobMatcher {
  GlobMatcher(this.pattern) : _expression = RegExp(_compile(pattern));

  final String pattern;
  final RegExp _expression;

  bool matches(String posixPath) {
    final normalized = posixPath
        .replaceAll('\\', '/')
        .replaceFirst(RegExp(r'^\./'), '')
        .replaceFirst(RegExp(r'^/'), '');
    return _expression.hasMatch(normalized);
  }

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

bool anyGlobMatches(Iterable<GlobMatcher> matchers, String posixPath) {
  for (final matcher in matchers) {
    if (matcher.matches(posixPath)) {
      return true;
    }
  }
  return false;
}
