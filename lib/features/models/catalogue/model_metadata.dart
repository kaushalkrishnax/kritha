import 'package:material_ui/material_ui.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme.dart';

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
  final String label;
  final ModelMetadataCategory category;
}

/// Classifies the Hub metadata returned for a repository.
///
/// The Hub mixes prefixed tags (`language:en`, `license:mit`) with bare library
/// and language identifiers, so both forms are resolved here.
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
    add(library, ModelMetadataCategory.libraries, _libraryLabel(library));
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
    final lower = normalized.toLowerCase();
    if (_libraryTags.contains(lower)) {
      add(
        normalized,
        ModelMetadataCategory.libraries,
        _libraryLabel(normalized),
      );
      continue;
    }
    final language = _languageNames[lower];
    if (language != null) {
      add(normalized, ModelMetadataCategory.languages, language);
      continue;
    }
    add(normalized, ModelMetadataCategory.other, normalized);
  }

  return List.unmodifiable(result);
}

/// Hub library identifiers, used to classify bare library tags such as
/// `pytorch` or `transformers` that carry no `library:` prefix.
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

const _libraryNames = <String, String>{
  'pytorch': 'PyTorch',
  'tf': 'TensorFlow',
  'jax': 'JAX',
  'safetensors': 'Safetensors',
  'transformers': 'Transformers',
  'peft': 'PEFT',
  'gguf': 'GGUF',
  'onnx': 'ONNX',
  'mlx': 'MLX',
  'nemo': 'NeMo',
  'spacy': 'spaCy',
  'sklearn': 'scikit-learn',
  'open_clip': 'OpenCLIP',
  'openvino': 'OpenVINO',
  'coreml': 'Core ML',
  'tflite': 'TensorFlow Lite',
  'tf-keras': 'TF-Keras',
  'transformers.js': 'Transformers.js',
  'sentence-transformers': 'Sentence Transformers',
  'stable-baselines3': 'Stable-Baselines3',
  'speechbrain': 'SpeechBrain',
  'fastai': 'fastai',
  'timm': 'timm',
  'keras': 'Keras',
  'keras-hub': 'KerasHub',
  'paddleocr': 'PaddleOCR',
  'paddlenlp': 'PaddleNLP',
};

String _libraryLabel(String value) =>
    _libraryNames[value.toLowerCase()] ?? _titleIdentifier(value);

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
