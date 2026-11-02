final class FlavorModel {
  const FlavorModel({
    required this.name,
    required this.applicationId,
    required this.applicationIdSuffix,
    required this.appName,
  });

  final String name;
  final String? applicationId;
  final String? applicationIdSuffix;
  final String? appName;

  String? resolvedId(String? defaultId) {
    if (applicationId != null) {
      return applicationId;
    }
    if (defaultId == null) {
      return null;
    }
    if (applicationIdSuffix == null) {
      return defaultId;
    }
    return '$defaultId$applicationIdSuffix';
  }
}

final class GradleModel {
  const GradleModel({
    required this.path,
    required this.applicationIds,
    required this.flavors,
    required this.releaseDebuggable,
    required this.releaseMinify,
    required this.minSdk,
    required this.hasReleaseBuildType,
  });

  final String path;
  final List<String> applicationIds;
  final List<FlavorModel> flavors;
  final bool releaseDebuggable;
  final bool? releaseMinify;
  final int? minSdk;
  final bool hasReleaseBuildType;
}

GradleModel parseGradle(String path, String text) {
  final flavorsBlock = _blockAfter(text, 'productFlavors');
  final flavors = <FlavorModel>[];
  if (flavorsBlock != null) {
    for (final flavor in _namedBlocks(flavorsBlock)) {
      flavors.add(
        FlavorModel(
          name: flavor.name,
          applicationId: _stringValue(flavor.body, 'applicationId'),
          applicationIdSuffix: _stringValue(flavor.body, 'applicationIdSuffix'),
          appName: _resValue(flavor.body, 'app_name'),
        ),
      );
    }
  }
  final release = _blockAfter(text, 'release');
  return GradleModel(
    path: path,
    applicationIds: _allStringValues(text, 'applicationId'),
    flavors: flavors,
    releaseDebuggable:
        release != null && _boolValue(release, 'debuggable') == true,
    releaseMinify: release == null
        ? null
        : _boolValue(release, 'minifyEnabled'),
    minSdk: _intValue(text, 'minSdk'),
    hasReleaseBuildType: release != null,
  );
}

final class _NamedBlock {
  const _NamedBlock(this.name, this.body);
  final String name;
  final String body;
}

String? _blockAfter(String text, String keyword) {
  final matcher = RegExp('\\b$keyword\\b');
  var start = 0;
  while (true) {
    final found =
        matcher.matchAsPrefix(text, start) ?? _search(text, matcher, start);
    if (found == null) {
      return null;
    }
    final index = found.end;
    final open = _nextBrace(text, index);
    if (open == null) {
      start = found.end;
      continue;
    }
    final close = _matchingBrace(text, open);
    if (close == null) {
      return null;
    }
    return text.substring(open + 1, close);
  }
}

RegExpMatch? _search(String text, RegExp matcher, int start) {
  final found = matcher.allMatches(text, start);
  return found.isEmpty ? null : found.first;
}

int? _nextBrace(String text, int start) {
  for (var i = start; i < text.length; i++) {
    if (text[i] == '{') {
      return i;
    }
    if (text[i] == '\n') {
      return null;
    }
  }
  return null;
}

int? _matchingBrace(String text, int open) {
  var depth = 0;
  var i = open;
  while (i < text.length) {
    if (text.startsWith('//', i)) {
      final newline = text.indexOf('\n', i);
      i = newline == -1 ? text.length : newline + 1;
      continue;
    }
    if (text.startsWith('/*', i)) {
      final end = text.indexOf('*/', i + 2);
      i = end == -1 ? text.length : end + 2;
      continue;
    }
    final char = text[i];
    if (char == '"' || char == "'") {
      i = _skipString(text, i);
      continue;
    }
    if (char == '{') {
      depth += 1;
    } else if (char == '}') {
      depth -= 1;
      if (depth == 0) {
        return i;
      }
    }
    i += 1;
  }
  return null;
}

int _skipString(String text, int start) {
  final quote = text[start];
  var i = start + 1;
  while (i < text.length) {
    if (text[i] == r'\') {
      i += 2;
      continue;
    }
    if (text[i] == quote) {
      return i + 1;
    }
    i += 1;
  }
  return text.length;
}

List<_NamedBlock> _namedBlocks(String body) {
  final blocks = <_NamedBlock>[];
  final pattern = RegExp(r'\b([A-Za-z_][A-Za-z0-9_]*)\s*\{');
  var searchFrom = 0;
  while (searchFrom < body.length) {
    final match =
        pattern.matchAsPrefix(body, searchFrom) ??
        pattern
            .allMatches(body, searchFrom)
            .cast<RegExpMatch?>()
            .firstWhere((item) => item != null, orElse: () => null);
    if (match == null) {
      break;
    }
    final open = match.end - 1;
    final close = _matchingBrace(body, open);
    if (close == null) {
      break;
    }
    blocks.add(_NamedBlock(match.group(1)!, body.substring(open + 1, close)));
    searchFrom = close + 1;
  }
  return blocks;
}

String? _stringValue(String text, String key) {
  final match = RegExp('\\b$key\\b\\s*=?\\s*[\'"]([^\'"]+)[\'"]')
      .firstMatch(text);
  return match?.group(1);
}

List<String> _allStringValues(String text, String key) {
  return [
    for (final match in RegExp(
      '\\b$key\\b\\s*=?\\s*[\'"]([^\'"]+)[\'"]',
    ).allMatches(text))
      match.group(1)!,
  ];
}

bool? _boolValue(String text, String key) {
  final match = RegExp('\\b$key\\s*=?\\s*(true|false)').firstMatch(text);
  if (match == null) {
    return null;
  }
  return match.group(1) == 'true';
}

int? _intValue(String text, String key) {
  final match = RegExp('\\b$key(?:Version)?\\s*=?\\s*(\\d+)').firstMatch(text);
  if (match == null) {
    return null;
  }
  return int.tryParse(match.group(1)!);
}

String? _resValue(String text, String name) {
  final match = RegExp(
    'resValue\\s*\\(?\\s*[\'"]string[\'"]\\s*,\\s*[\'"]$name[\'"]\\s*,\\s*[\'"]([^\'"]+)[\'"]',
  ).firstMatch(text);
  return match?.group(1);
}
