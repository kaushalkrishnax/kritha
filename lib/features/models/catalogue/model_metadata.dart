import 'package:hugeicons/hugeicons.dart';

/// The five metadata groups shown on a model repository.
///
/// `null` represents the combined "Main" view; it is not a metadata category.
enum ModelMetadataCategory {
  tasks('Tasks', HugeIcons.strokeRoundedTask01),
  libraries('Libraries', HugeIcons.strokeRoundedArchive01),
  languages('Languages', HugeIcons.strokeRoundedGlobe02),
  licenses('Licenses', HugeIcons.strokeRoundedSoftwareLicense),
  other('Other', HugeIcons.strokeRoundedBlockchain01);

  const ModelMetadataCategory(this.label, this.icon);

  final String label;
  final List<List<dynamic>> icon;
}

class ModelMetadataTag {
  const ModelMetadataTag({
    required this.raw,
    required this.label,
    required this.category,
  });

  /// The untouched Hub identifier used by the API.
  final String raw;
  final String label;
  final ModelMetadataCategory category;
}

/// Classifies the Hub metadata returned for a repository.
///
/// Classification only looks at the fields the Hub documents, so new values
/// flow into the correct group without a maintained tag list.
List<ModelMetadataTag> classifyModelMetadata({
  required String? pipelineTag,
  required String? libraryName,
  required List<String> tags,
}) {
  final result = <ModelMetadataTag>[];
  final seen = <String>{};

  void add(String raw, ModelMetadataCategory category, String label) {
    final normalized = raw.trim();
    if (normalized.isEmpty || !seen.add(normalized)) return;
    result.add(
      ModelMetadataTag(raw: normalized, label: label, category: category),
    );
  }

  final task = pipelineTag?.trim();
  if (task != null && task.isNotEmpty) {
    add(task, ModelMetadataCategory.tasks, _titleIdentifier(task));
  }

  final library = libraryName?.trim();
  if (library != null && library.isNotEmpty) {
    add(library, ModelMetadataCategory.libraries, _titleIdentifier(library));
  }

  for (final tag in tags) {
    final normalized = tag.trim();
    if (normalized.isEmpty) continue;
    if (normalized.startsWith('language:')) {
      final value = normalized.substring('language:'.length).trim();
      if (value.isEmpty) continue;
      add(normalized, ModelMetadataCategory.languages, _languageLabel(value));
      continue;
    }
    if (normalized.startsWith('license:')) {
      final value = normalized.substring('license:'.length).trim();
      if (value.isEmpty) continue;
      add(normalized, ModelMetadataCategory.licenses, _licenseLabel(value));
      continue;
    }
    add(normalized, ModelMetadataCategory.other, normalized);
  }

  return List.unmodifiable(result);
}

List<ModelMetadataTag> metadataForCategory(
  List<ModelMetadataTag> tags,
  ModelMetadataCategory? category,
) => category == null
    ? tags
    : List.unmodifiable(tags.where((tag) => tag.category == category));

String _titleIdentifier(String value) => value
    .split(RegExp(r'[-_\s]+'))
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _languageLabel(String code) {
  final normalized = code.toLowerCase();
  return _languageNames[normalized] ?? normalized.toUpperCase();
}

const _languageNames = <String, String>{
  'ar': 'Arabic',
  'bn': 'Bengali',
  'cs': 'Czech',
  'da': 'Danish',
  'de': 'German',
  'el': 'Greek',
  'en': 'English',
  'es': 'Spanish',
  'fa': 'Persian',
  'fi': 'Finnish',
  'fr': 'French',
  'he': 'Hebrew',
  'hi': 'Hindi',
  'hu': 'Hungarian',
  'id': 'Indonesian',
  'it': 'Italian',
  'ja': 'Japanese',
  'ko': 'Korean',
  'ms': 'Malay',
  'nl': 'Dutch',
  'no': 'Norwegian',
  'pl': 'Polish',
  'pt': 'Portuguese',
  'ro': 'Romanian',
  'ru': 'Russian',
  'sv': 'Swedish',
  'ta': 'Tamil',
  'th': 'Thai',
  'tr': 'Turkish',
  'uk': 'Ukrainian',
  'ur': 'Urdu',
  'vi': 'Vietnamese',
  'zh': 'Chinese',
};

String _licenseLabel(String value) {
  const acronyms = {
    'mit',
    'bsd',
    'gpl',
    'lgpl',
    'agpl',
    'mpl',
    'epl',
    'cc',
    'cddl',
    'odc',
    'wtfpl',
    'afl',
    'bsl',
    'ofl',
    'isc',
    'cc0',
    'gfdl',
    'zlib',
  };
  const clauses = {'by', 'nc', 'sa', 'nd'};
  return value
      .split('-')
      .where((part) => part.isNotEmpty)
      .map((part) {
        final lower = part.toLowerCase();
        if (acronyms.contains(lower)) return lower.toUpperCase();
        if (clauses.contains(lower)) return lower.toUpperCase();
        return '${part[0].toUpperCase()}${part.substring(1)}';
      })
      .join(' ');
}
