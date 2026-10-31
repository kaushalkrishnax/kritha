/// Comparison form for identifiers: case and separators are ignored.
String normalizeModelIdentifier(String value) =>
    value.toLowerCase().replaceAll(_identifierSeparator, '');

final _identifierSeparator = RegExp(r'[^a-z0-9]');

bool modelIdentifiersMatch(String? a, String? b) {
  if (a == null || b == null) return false;
  final left = normalizeModelIdentifier(a);
  return left.isNotEmpty && left == normalizeModelIdentifier(b);
}

/// Whether declared formats agree with the library; non-format libraries never mismatch.
bool declaredFormatMatchesLibrary({
  required Iterable<String> formats,
  required String? libraryName,
}) {
  final library = libraryName;
  if (library == null || library.trim().isEmpty) return true;
  if (!_formatIdentifiers.contains(normalizeModelIdentifier(library))) {
    return true;
  }
  final declared = formats.where((format) => format.trim().isNotEmpty);
  if (declared.isEmpty) return true;
  return declared.any((format) => modelIdentifiersMatch(format, library));
}

/// Already normalised, so `litert-lm` maps to `litertlm`.
const _formatIdentifiers = <String>{
  'litertlm',
  'gguf',
  'safetensors',
  'onnx',
  'pytorch',
  'tensorflow',
  'mlx',
};
