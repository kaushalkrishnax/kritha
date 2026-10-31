import 'package:material_ui/material_ui.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme.dart';
import 'model_identifiers.dart';

/// The five metadata groups shown on a model repository.
enum ModelMetadataCategory {
  tasks('Tasks', HugeIcons.strokeRoundedTask01),
  libraries('Libraries', HugeIcons.strokeRoundedArchive01),
  languages('Languages', HugeIcons.strokeRoundedGlobe02),
  licenses('Licenses', HugeIcons.strokeRoundedSoftwareLicense),
  other('Other', null);

  const ModelMetadataCategory(this.label, this.icon);

  final String label;
  final List<List<dynamic>>? icon;

  Color get color => switch (this) {
    tasks => KrithaColors.error,
    libraries => KrithaColors.accentLightBlue,
    languages => KrithaColors.success,
    licenses => KrithaColors.textPrimary,
    other => KrithaColors.textMuted,
  };
}

class ModelMetadataTag {
  const ModelMetadataTag({
    required this.raw,
    required this.label,
    required this.category,
  });

  /// The untouched Hub identifier used by the API.
  final String raw;

  /// The exact API value; tags are never rewritten for display.
  final String label;
  final ModelMetadataCategory category;

  /// Comparison-only form. Never use this for display.
  String get normalized => normalizeModelIdentifier(raw);
}

/// Classifies Hub metadata; tags are prefixed (`language:en`) or bare identifiers.
List<ModelMetadataTag> classifyModelMetadata({
  required String? pipelineTag,
  required String? libraryName,
  required List<String> tags,
}) {
  final result = <ModelMetadataTag>[];
  final seen = <String>{};

  void add(String raw, ModelMetadataCategory category) {
    final normalized = raw.trim();
    if (normalized.isEmpty || !seen.add(normalizeModelIdentifier(normalized))) {
      return;
    }
    result.add(
      ModelMetadataTag(raw: normalized, label: normalized, category: category),
    );
  }

  final task = pipelineTag?.trim();
  if (task != null && task.isNotEmpty) {
    add(task, ModelMetadataCategory.tasks);
  }

  final library = libraryName?.trim();
  if (library != null && library.isNotEmpty) {
    add(library, ModelMetadataCategory.libraries);
  }

  for (final tag in tags) {
    final normalized = tag.trim();
    if (normalized.isEmpty) continue;
    if (normalized.startsWith('language:')) {
      final value = normalized.substring('language:'.length).trim();
      if (value.isEmpty) continue;
      add(normalized, ModelMetadataCategory.languages);
      continue;
    }
    if (normalized.startsWith('license:')) {
      final value = normalized.substring('license:'.length).trim();
      if (value.isEmpty) continue;
      add(normalized, ModelMetadataCategory.licenses);
      continue;
    }
    final lower = normalizeModelIdentifier(normalized);
    if (_normalizedLibraryTags.contains(lower)) {
      add(normalized, ModelMetadataCategory.libraries);
      continue;
    }
    if (_languageNames.containsKey(lower)) {
      add(normalized, ModelMetadataCategory.languages);
      continue;
    }
    add(normalized, ModelMetadataCategory.other);
  }

  return List.unmodifiable(result);
}

/// Hub library identifiers used to classify bare tags such as `pytorch`.
const _libraryTags = <String>{
  'pytorch',
  'tf',
  'jax',
  'safetensors',
  'transformers',
  'peft',
  'gguf',
  'tensorboard',
  'diffusers',
  'onnx',
  'stable-baselines3',
  'mlx',
  'sentence-transformers',
  'ml-agents',
  'keras',
  'tf-keras',
  'joblib',
  'transformers.js',
  'adapter-transformers',
  'timm',
  'openvino',
  'setfit',
  'coreml',
  'sample-factory',
  'tflite',
  'nemo',
  'flair',
  'rust',
  'sklearn',
  'fastai',
  'espnet',
  'bertopic',
  'spacy',
  'executorch',
  'fasttext',
  'open_clip',
  'microduck',
  'keras-hub',
  'speechbrain',
  'asteroid',
  'llamafile',
  'allennlp',
  'paddlepaddle',
  'paddleocr',
  'fairseq',
  'stanza',
  'pyannote-audio',
  'optimum_habana',
  'span-marker',
  'optimum_graphcore',
  'unity-sentis',
  'paddlenlp',
  'dduf',
  'univa',
};

/// Lookup form of [_libraryTags]; separators are not significant.
final _normalizedLibraryTags = {
  for (final tag in _libraryTags) normalizeModelIdentifier(tag),
};

const _languageNames = <String, String>{
  'af': 'Afrikaans',
  'ar': 'Arabic',
  'az': 'Azerbaijani',
  'be': 'Belarusian',
  'bg': 'Bulgarian',
  'bn': 'Bengali',
  'bs': 'Bosnian',
  'ca': 'Catalan',
  'cs': 'Czech',
  'cy': 'Welsh',
  'da': 'Danish',
  'de': 'German',
  'el': 'Greek',
  'en': 'English',
  'es': 'Spanish',
  'et': 'Estonian',
  'eu': 'Basque',
  'fa': 'Persian',
  'fi': 'Finnish',
  'fr': 'French',
  'ga': 'Irish',
  'gl': 'Galician',
  'gu': 'Gujarati',
  'he': 'Hebrew',
  'hi': 'Hindi',
  'hr': 'Croatian',
  'hu': 'Hungarian',
  'hy': 'Armenian',
  'id': 'Indonesian',
  'is': 'Icelandic',
  'it': 'Italian',
  'ja': 'Japanese',
  'ka': 'Georgian',
  'kk': 'Kazakh',
  'km': 'Khmer',
  'kn': 'Kannada',
  'ko': 'Korean',
  'lt': 'Lithuanian',
  'lv': 'Latvian',
  'mk': 'Macedonian',
  'ml': 'Malayalam',
  'mn': 'Mongolian',
  'mr': 'Marathi',
  'ms': 'Malay',
  'mt': 'Maltese',
  'my': 'Burmese',
  'ne': 'Nepali',
  'nl': 'Dutch',
  'no': 'Norwegian',
  'pa': 'Punjabi',
  'pl': 'Polish',
  'ps': 'Pashto',
  'pt': 'Portuguese',
  'ro': 'Romanian',
  'ru': 'Russian',
  'si': 'Sinhala',
  'sk': 'Slovak',
  'sl': 'Slovenian',
  'so': 'Somali',
  'sq': 'Albanian',
  'sr': 'Serbian',
  'sv': 'Swedish',
  'sw': 'Swahili',
  'ta': 'Tamil',
  'te': 'Telugu',
  'th': 'Thai',
  'tl': 'Tagalog',
  'tr': 'Turkish',
  'uk': 'Ukrainian',
  'ur': 'Urdu',
  'uz': 'Uzbek',
  'vi': 'Vietnamese',
  'yi': 'Yiddish',
  'zh': 'Chinese',
  'zu': 'Zulu',
};
