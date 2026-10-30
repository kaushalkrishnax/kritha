import 'hugging_face_urls.dart';

/// A capability a repository advertises or an execution path can serve.
enum ModelCapability {
  text(
    label: 'Text',
    description: 'Chat and text generation',
    pipelineTag: 'text-generation',
  ),
  vision(
    label: 'Vision',
    description: 'Image understanding',
    pipelineTag: 'image-text-to-text',
  ),
  imageGeneration(
    label: 'Image generation',
    description: 'Text and image to image',
    pipelineTag: 'text-to-image',
  ),
  speechRecognition(
    label: 'Speech recognition',
    description: 'Speech to text',
    pipelineTag: 'automatic-speech-recognition',
  ),
  textToSpeech(
    label: 'Text to speech',
    description: 'Speech synthesis',
    pipelineTag: 'text-to-speech',
  ),
  audio(
    label: 'Audio',
    description: 'Audio understanding',
    pipelineTag: 'audio-classification',
  ),
  video(
    label: 'Video understanding',
    description: 'Video understanding',
    pipelineTag: 'video-text-to-text',
  ),
  embeddings(
    label: 'Embeddings',
    description: 'Feature extraction and retrieval',
    pipelineTag: 'feature-extraction',
  );

  const ModelCapability({
    required this.label,
    required this.description,
    required this.pipelineTag,
  });

  final String label;
  final String description;
  final String pipelineTag;

  static const Map<String, ModelCapability> _byPipelineTag = {
    'text-generation': ModelCapability.text,
    'text2text-generation': ModelCapability.text,
    'text-classification': ModelCapability.text,
    'token-classification': ModelCapability.text,
    'question-answering': ModelCapability.text,
    'summarization': ModelCapability.text,
    'translation': ModelCapability.text,
    'fill-mask': ModelCapability.text,
    'image-text-to-text': ModelCapability.vision,
    'image-to-text': ModelCapability.vision,
    'visual-question-answering': ModelCapability.vision,
    'image-classification': ModelCapability.vision,
    'object-detection': ModelCapability.vision,
    'image-segmentation': ModelCapability.vision,
    'depth-estimation': ModelCapability.vision,
    'text-to-image': ModelCapability.imageGeneration,
    'image-to-image': ModelCapability.imageGeneration,
    'unconditional-image-generation': ModelCapability.imageGeneration,
    'automatic-speech-recognition': ModelCapability.speechRecognition,
    'audio-classification': ModelCapability.audio,
    'text-to-speech': ModelCapability.textToSpeech,
    'voice-activity-detection': ModelCapability.audio,
    'video-classification': ModelCapability.video,
    'video-text-to-text': ModelCapability.video,
    'feature-extraction': ModelCapability.embeddings,
    'sentence-similarity': ModelCapability.embeddings,
  };

  static ModelCapability? fromPipelineTag(String? tag) {
    if (tag == null) return null;
    return _byPipelineTag[tag.trim().toLowerCase()];
  }

  static List<ModelCapability> fromTags(
    String? pipelineTag,
    List<String> tags,
  ) {
    final result = <ModelCapability>{};
    final primary = fromPipelineTag(pipelineTag);
    if (primary != null) result.add(primary);
    for (final tag in tags) {
      final capability = fromPipelineTag(tag);
      if (capability != null) result.add(capability);
    }
    return List.unmodifiable(result);
  }

  static const discoverable = [
    ModelCapability.text,
    ModelCapability.vision,
    ModelCapability.speechRecognition,
    ModelCapability.audio,
    ModelCapability.video,
    ModelCapability.embeddings,
  ];
}

const _generationTasks = {
  'text-to-image',
  'image-to-image',
  'unconditional-image-generation',
  'text-to-audio',
  'text-to-speech',
  'audio-to-audio',
  'text-to-video',
  'image-to-video',
  'video-to-video',
};

const _knownTasks = {
  ..._generationTasks,
  'text-generation',
  'text2text-generation',
  'text-classification',
  'token-classification',
  'question-answering',
  'summarization',
  'translation',
  'fill-mask',
  'image-text-to-text',
  'image-to-text',
  'visual-question-answering',
  'image-classification',
  'object-detection',
  'image-segmentation',
  'depth-estimation',
  'automatic-speech-recognition',
  'audio-classification',
  'voice-activity-detection',
  'video-classification',
  'video-text-to-text',
  'feature-extraction',
  'sentence-similarity',
};

/// Hub list ordering. Direction is always newest/most first (`-1`).
enum CatalogueSort {
  trending(label: 'Trending', apiValue: 'trendingScore'),
  likes(label: 'Most likes', apiValue: 'likes'),
  downloads(label: 'Most downloads', apiValue: 'downloads'),
  recentlyCreated(label: 'Recently created', apiValue: 'createdAt'),
  recentlyUpdated(label: 'Recently updated', apiValue: 'lastModified'),
  mostParameters(label: 'Most parameters', apiValue: 'downloads'),
  leastParameters(label: 'Least parameters', apiValue: 'downloads');

  const CatalogueSort({required this.label, required this.apiValue});

  final String label;
  final String apiValue;

  /// The Hub has no parameter-count ordering, so these sorts order the fetched
  /// page locally instead of asking the API for a field it does not expose.
  bool get sortsByParameters =>
      this == CatalogueSort.mostParameters ||
      this == CatalogueSort.leastParameters;
}

/// One repository in a Hub list response.
class CatalogueModel {
  const CatalogueModel({
    required this.id,
    this.pipelineTag,
    this.libraryName,
    this.tags = const [],
    this.downloads = 0,
    this.likes = 0,
    this.createdAt,
    this.lastModified,
    this.gated = false,
    this.isPrivate = false,
    this.disabled = false,
    this.license,
    this.author,
    this.parameterCount,
    this.sha,
    this.usedStorage,
  });

  /// `namespace/repository`.
  final String id;
  final String? pipelineTag;
  final String? libraryName;
  final List<String> tags;
  final int downloads;
  final int likes;
  final DateTime? createdAt;
  final DateTime? lastModified;
  final bool gated;
  final bool isPrivate;
  final bool disabled;
  final String? license;
  final String? author;
  final int? parameterCount;
  final String? sha;
  final int? usedStorage;

  String get namespace {
    final slash = id.indexOf('/');
    return slash < 0 ? '' : id.substring(0, slash);
  }

  String get name {
    final slash = id.indexOf('/');
    return slash < 0 ? id : id.substring(slash + 1);
  }

  List<ModelCapability> get capabilities =>
      ModelCapability.fromTags(pipelineTag, tags);

  bool get hasCapabilities => capabilities.isNotEmpty;

  String? get declaredTask {
    final primary = pipelineTag?.toLowerCase();
    if (primary != null) return primary;
    for (final tag in tags) {
      final normalized = tag.toLowerCase();
      if (_knownTasks.contains(normalized)) return normalized;
    }
    return null;
  }

  bool get hasDiscoverableTask => !_generationTasks.contains(declaredTask);

  String get publisherLabel => _displayPublisher(publisher);

  String get publisher => author ?? namespace;

  String? get taskLabel {
    final task = declaredTask;
    if (task == null || task.isEmpty) return null;
    return task
        .split('-')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join('-');
  }

  factory CatalogueModel.fromJson(Map<String, dynamic> json) {
    final rawId = _string(json['modelId']) ?? _string(json['id']) ?? '';
    final cardData = _map(json['cardData']);
    return CatalogueModel(
      id: rawId,
      pipelineTag: _string(json['pipeline_tag']),
      libraryName: _string(json['library_name']),
      tags: _stringList(json['tags']),
      downloads: _int(json['downloads']),
      likes: _int(json['likes']),
      createdAt: _dateTime(json['createdAt']),
      lastModified: _dateTime(json['lastModified']),
      gated: _gated(json['gated']),
      isPrivate: _bool(json['private']),
      disabled: _bool(json['disabled']),
      license:
          _string(cardData?['license']) ??
          _string(json['license']) ??
          _licenseTag(json['tags']),
      author: _string(json['author']) ?? _string(json['authorName']),
      parameterCount: _parameterCount(json),
      sha: _string(json['sha']),
      usedStorage: _intOrNull(json['usedStorage']),
    );
  }
}

class ModelFile {
  const ModelFile({
    required this.path,
    this.sizeBytes,
    this.isLfs = false,
    this.type = 'file',
    this.oid,
  });

  final String path;
  final int? sizeBytes;
  final bool isLfs;
  final String type;
  final String? oid;

  bool get isDirectory => type == 'directory';

  bool get isLitertLm =>
      !isDirectory && path.toLowerCase().endsWith('.litertlm');

  String get name {
    final clean = path.endsWith('/')
        ? path.substring(0, path.length - 1)
        : path;
    final slash = clean.lastIndexOf('/');
    return slash < 0 ? clean : clean.substring(slash + 1);
  }

  String get readableSize {
    if (isDirectory) return '';
    final size = sizeBytes;
    if (size == null || size <= 0) return '—';
    return formatBytes(size);
  }

  factory ModelFile.fromJson(Map<String, dynamic> json) {
    final lfs = _map(json['lfs']);
    return ModelFile(
      path: _string(json['path']) ?? '',
      sizeBytes: _intOrNull(json['size']) ?? _intOrNull(lfs?['size']),
      isLfs: lfs != null,
      type: _string(json['type']) ?? 'file',
      oid: _string(json['oid']),
    );
  }
}

String formatBytes(int size) {
  if (size <= 0) return '—';
  if (size < 1024) return '$size B';
  if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
  if (size < 1024 * 1024 * 1024) {
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

class ModelPage {
  const ModelPage({required this.models, this.nextCursor});

  final List<CatalogueModel> models;
  final String? nextCursor;
}

List<CatalogueModel> filterDiscoverableModels(
  Iterable<CatalogueModel> models,
) => List.unmodifiable(models.where((model) => model.hasDiscoverableTask));

/// A repository plus the extra detail endpoints the details screen needs.
class ModelDetails {
  const ModelDetails({
    required this.model,
    this.files = const [],
    this.readme,
    this.cardData = const {},
    this.config = const {},
    this.safetensors = const {},
    this.publisher,
    this.branch = 'main',
  });

  final CatalogueModel model;
  final List<ModelFile> files;
  final String? readme;
  final Map<String, dynamic> cardData;
  final Map<String, dynamic> config;
  final Map<String, dynamic> safetensors;
  final HubPublisher? publisher;
  final String branch;

  String get repositoryUrl => HuggingFaceUrls.repository(model.id);

  String? get commitSha => model.sha;

  String? get commitUrl {
    final sha = model.sha;
    return sha == null ? null : HuggingFaceUrls.commit(model.id, sha);
  }

  String? fileUrl(ModelFile file) {
    if (file.path.isEmpty) return null;
    return HuggingFaceUrls.blob(model.id, branch, file.path);
  }

  String? directoryUrl(ModelFile directory) {
    if (directory.path.isEmpty) return null;
    return HuggingFaceUrls.tree(model.id, branch, directory.path);
  }

  bool get hasLitertLmFile => files.any((file) => file.isLitertLm);

  String? get architecture {
    final architectures = config['architectures'];
    if (architectures is List && architectures.isNotEmpty) {
      final first = architectures.first;
      if (first is String && first.trim().isNotEmpty) return first;
    }
    return _string(config['model_type']) ??
        _string(_map(config['text_config'])?['model_type']);
  }

  String? get modelType =>
      _string(config['model_type']) ??
      _string(_map(config['text_config'])?['model_type']);

  String? get libraryName => model.libraryName;

  int? get parameterCount => model.parameterCount;

  int? get contextLength =>
      _intOrNull(config['max_position_embeddings']) ??
      _intOrNull(_map(config['text_config'])?['max_position_embeddings']);

  List<String> get weightPrecisions {
    final parameters = _map(safetensors['parameters']);
    if (parameters == null) return const [];
    return List.unmodifiable([
      for (final key in parameters.keys)
        if (key.trim().isNotEmpty && key != 'total') key.trim(),
    ]);
  }

  List<String> get quantizations {
    final found = <String>{};
    final quantization =
        _map(config['quantization_config']) ??
        _map(_map(config['text_config'])?['quantization_config']);
    if (quantization != null) {
      final method = _string(quantization['quant_method']);
      if (method != null) found.add(_titleIdentifier(method));
      final bits =
          _intOrNull(quantization['bits']) ?? _intOrNull(quantization['w_bit']);
      if (bits != null && bits > 0) found.add('$bits-bit');
      if (quantization['load_in_4bit'] == true) found.add('4-bit');
      if (quantization['load_in_8bit'] == true) found.add('8-bit');
    }
    for (final tag in model.tags) {
      final lower = tag.toLowerCase();
      final bitMatch = RegExp(r'(\d+)[-_]?bit').firstMatch(lower);
      if (bitMatch != null) found.add('${bitMatch.group(1)}-bit');
      for (final method in const [
        'awq',
        'gptq',
        'fp8',
        'int8',
        'int4',
        'nf4',
      ]) {
        if (lower == method ||
            lower.endsWith(':$method') ||
            lower.contains('$method-')) {
          found.add(method.toUpperCase());
        }
      }
    }
    return List.unmodifiable(found);
  }

  int get repositorySize {
    final storage = model.usedStorage;
    if (storage != null && storage > 0) return storage;
    return files.fold<int>(
      0,
      (total, file) => total + (file.isDirectory ? 0 : (file.sizeBytes ?? 0)),
    );
  }

  List<String> get formats {
    const known = {
      'gguf': 'GGUF',
      'safetensors': 'Safetensors',
      'onnx': 'ONNX',
      'pytorch': 'PyTorch',
      'tensorflow': 'TensorFlow',
      'mlx': 'MLX',
      'litertlm': 'LiteRT-LM',
    };
    final found = <String>{};
    for (final entry in known.entries) {
      if (model.tags.any((tag) => tag.toLowerCase() == entry.key)) {
        found.add(entry.value);
      }
    }
    for (final file in files) {
      if (file.isDirectory) continue;
      final lower = file.path.toLowerCase();
      if (lower.endsWith('.litertlm')) found.add('LiteRT-LM');
      if (lower.endsWith('.gguf')) found.add('GGUF');
      if (lower.endsWith('.safetensors')) found.add('Safetensors');
      if (lower.endsWith('.onnx')) found.add('ONNX');
    }
    return List.unmodifiable(found);
  }

  factory ModelDetails.fromJson(
    Map<String, dynamic> json, {
    List<ModelFile> files = const [],
    String? readme,
    HubPublisher? publisher,
    String branch = 'main',
  }) {
    return ModelDetails(
      model: CatalogueModel.fromJson(json),
      files: List.unmodifiable(files),
      readme: readme,
      cardData: _map(json['cardData']) ?? const {},
      config: _map(json['config']) ?? const {},
      safetensors: _map(json['safetensors']) ?? const {},
      publisher: publisher,
      branch: branch,
    );
  }
}

class HubPublisher {
  const HubPublisher({
    required this.name,
    required this.displayName,
    required this.avatarUrl,
    required this.isOrganization,
    this.followers = 0,
    this.following = 0,
    this.isFollowing = false,
    this.isVerified = false,
  });

  final String name;
  final String displayName;
  final String? avatarUrl;
  final bool isOrganization;
  final int followers;
  final int following;
  final bool isFollowing;
  final bool isVerified;

  factory HubPublisher.fromJson(
    Map<String, dynamic> json, {
    required String fallbackName,
    required bool organization,
  }) {
    final name = _string(json['name']) ?? _string(json['user']) ?? fallbackName;
    final fullName = _string(json['fullname']);
    final rawAvatar = _string(json['avatarUrl']);
    final avatar = rawAvatar == null
        ? null
        : rawAvatar.startsWith('http')
        ? rawAvatar
        : '${HuggingFaceUrls.origin}$rawAvatar';
    return HubPublisher(
      name: name,
      displayName: fullName ?? name,
      avatarUrl: avatar,
      isOrganization: organization || _string(json['type']) == 'org',
      followers: _intOrNull(json['numFollowers']) ?? 0,
      following: _intOrNull(json['numFollowing']) ?? 0,
      isFollowing: json['isFollowing'] == true,
      isVerified: json['isVerified'] == true,
    );
  }
}

class HubAccount {
  const HubAccount({required this.name, this.fullName, this.plan});

  final String name;
  final String? fullName;
  final String? plan;

  factory HubAccount.fromJson(Map<String, dynamic> json) {
    return HubAccount(
      name:
          _string(json['name']) ??
          _string(json['preferred_username']) ??
          'Hugging Face user',
      fullName: _string(json['fullname']),
      plan: _string(json['plan']),
    );
  }
}

String formatCount(int value) {
  if (value < 1000) return '$value';
  if (value < 1000000) {
    final thousands = value / 1000;
    return '${thousands.toStringAsFixed(thousands >= 100 ? 0 : 1)}k';
  }
  final millions = value / 1000000;
  return '${millions.toStringAsFixed(millions >= 100 ? 0 : 1)}M';
}

String formatParameterCount(int value) {
  final (divisor, suffix) = switch (value) {
    >= 1000000000 => (1000000000.0, 'B'),
    >= 1000000 => (1000000.0, 'M'),
    >= 1000 => (1000.0, 'K'),
    _ => (1.0, ''),
  };
  final scaled = value / divisor;
  final text = scaled.toStringAsFixed(scaled >= 100 ? 0 : 1);
  final trimmed = text.endsWith('.0')
      ? text.substring(0, text.length - 2)
      : text;
  return '$trimmed$suffix';
}

String? _string(Object? value) {
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  return null;
}

int _int(Object? value) => _intOrNull(value) ?? 0;

int? _intOrNull(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

int? _parameterCount(Map<String, dynamic> json) {
  final safetensors = _map(json['safetensors']);
  final total = _intOrNull(safetensors?['total']);
  if (total != null && total > 0) return total;
  final parameters = _map(safetensors?['parameters']);
  if (parameters == null) return null;
  final count = parameters.values.fold<int>(
    0,
    (sum, value) => sum + (_intOrNull(value) ?? 0),
  );
  return count > 0 ? count : null;
}

String _displayPublisher(String value) => value
    .split(RegExp(r'[-_\s]+'))
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _titleIdentifier(String value) => value
    .split(RegExp(r'[-_\s]+'))
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

bool _bool(Object? value) => value == true;

bool _gated(Object? value) {
  if (value is bool) return value;
  if (value is String) return value != 'false';
  return false;
}

DateTime? _dateTime(Object? value) {
  final raw = _string(value);
  if (raw == null) return null;
  return DateTime.tryParse(raw)?.toLocal();
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return List.unmodifiable([
    for (final item in value)
      if (item is String && item.trim().isNotEmpty) item.trim(),
  ]);
}

Map<String, dynamic>? _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return {for (final entry in value.entries) '${entry.key}': entry.value};
  }
  return null;
}

String? _licenseTag(Object? tags) {
  if (tags is! List) return null;
  for (final tag in tags) {
    if (tag is! String) continue;
    if (tag.startsWith('license:')) {
      final value = tag.substring('license:'.length).trim();
      if (value.isNotEmpty) return value;
    }
  }
  return null;
}
