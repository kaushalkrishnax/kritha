import 'package:tldts/data/trie.dart' as psl;

/// Normalizes alias into hyphenated lowercase key for uniqueness checks.
String normalizeProviderAlias(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return normalized;
}

/// Cleans user-facing alias while preserving capitalization and spaces.
String cleanProviderAlias(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ');
}

/// Derives title-cased alias from hostname labels excluding public suffix and port.
String? deriveProviderAlias(String rawUrl) {
  final uri = Uri.tryParse(rawUrl.trim());
  if (uri == null ||
      !(uri.scheme == 'http' || uri.scheme == 'https') ||
      uri.host.isEmpty) {
    return null;
  }

  final host = uri.host.toLowerCase().replaceAll(RegExp(r'\.+$'), '');
  if (host == 'localhost' ||
      host == '127.0.0.1' ||
      host == '::1' ||
      host.contains(':')) {
    return null;
  }

  final parts = _registrableParts(host);
  if (parts == null) return null;

  final labels = [
    parts.domainWithoutSuffix,
    for (final label in parts.subdomain.split('.'))
      if (label.isNotEmpty && label != 'www') label,
  ];
  final alias = cleanProviderAlias(
    labels.map(_titleCaseLabel).where((label) => label.isNotEmpty).join(' '),
  );
  return alias.isEmpty ? null : alias;
}

bool isValidProviderAlias(String alias) {
  final cleaned = cleanProviderAlias(alias);
  return cleaned.isNotEmpty &&
      cleaned.length <= 48 &&
      RegExp(r'^[A-Za-z0-9](?:[A-Za-z0-9 _-]*[A-Za-z0-9])?$').hasMatch(cleaned);
}

String _titleCaseLabel(String label) {
  return label
      .split(RegExp(r'[^A-Za-z0-9]+'))
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
      .join(' ');
}

typedef _RegistrableParts = ({String subdomain, String domainWithoutSuffix});

_RegistrableParts? _registrableParts(String host) {
  final labels = host.split('.');
  if (labels.length < 2) return null;

  // Read trie directly for correct multi-label suffix parsing without private PSL exclusions.
  final exception = _lookupSuffix(labels, psl.exceptions);
  final match = exception == null
      ? _lookupSuffix(labels, psl.rules)
      : (index: exception.index + 1);
  if (match == null) return null;

  final suffixLabels = labels.length - match.index;
  if (suffixLabels <= 0 || suffixLabels >= labels.length) return null;

  final domainStart = match.index - 1;
  return (
    subdomain: labels.sublist(0, domainStart).join('.'),
    domainWithoutSuffix: labels[domainStart],
  );
}

({int index})? _lookupSuffix(List<String> labels, List<dynamic> trie) {
  ({int index})? result;
  dynamic node = trie;
  var index = labels.length - 1;

  while (node != null) {
    final ruleType = node[0] as int;
    if (ruleType == 1) {
      result = (index: index + 1);
    }
    if (index == -1) break;
    final Map<dynamic, dynamic> children = node[1] as Map<dynamic, dynamic>;
    node = children.containsKey(labels[index])
        ? children[labels[index]]
        : children['*'];
    index -= 1;
  }
  return result;
}
