import '../features/intelligence/models/ai_request.dart';
import '../features/intelligence/models/task_registry.dart';

/// Unified application-side model identity.
///
/// [id] is the internal model UUID assigned at discovery time and preserved
/// across rediscovery. [providerId] identifies which provider executes the
/// model; [externalModelId] is the identifier used by that provider or
/// runtime. Origin (e.g. Hugging Face) is intentionally not stored here.
class ModelRecord {
  const ModelRecord({
    required this.id,
    required this.providerId,
    required this.externalModelId,
    required this.displayName,
    required this.createdAt,
    required this.updatedAt,
    this.parentModelId,
    this.suffix,
    this.publisher,
    this.metadata = const {},
    this.tasks = const [],
  });

  final String id;
  final String providerId;

  /// Identifier used by the provider or runtime executing this model.
  final String externalModelId;
  final String displayName;
  final String? parentModelId;
  final String? suffix;
  final String? publisher;
  final Map<String, dynamic> metadata;
  final List<TaskDeclaration> tasks;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isVariant => parentModelId != null;
  bool get isBaseModel => parentModelId == null;

  ModelRecord copyWith({
    String? displayName,
    String? parentModelId,
    String? suffix,
    String? publisher,
    Map<String, dynamic>? metadata,
    List<TaskDeclaration>? tasks,
    DateTime? updatedAt,
  }) {
    return ModelRecord(
      id: id,
      providerId: providerId,
      externalModelId: externalModelId,
      displayName: displayName ?? this.displayName,
      parentModelId: parentModelId ?? this.parentModelId,
      suffix: suffix ?? this.suffix,
      publisher: publisher ?? this.publisher,
      metadata: metadata ?? this.metadata,
      tasks: tasks ?? this.tasks,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Lean, model-owned artifact record.
class ModelArtifactRecord {
  const ModelArtifactRecord({
    required this.id,
    required this.modelId,
    required this.externalPath,
    required this.createdAt,
    required this.updatedAt,
    this.kind = 'other',
    this.sourceType = 'repository',
    this.targetPath,
    this.format,
    this.sizeBytes,
    this.enabled = true,
    this.position = 0,
  });

  final String id;
  final String modelId;

  /// Original source path or location, interpreted with [sourceType].
  final String externalPath;
  final String kind;
  final String sourceType;

  /// Relative destination inside the owning model's storage directory.
  final String? targetPath;
  final String? format;
  final int? sizeBytes;
  final bool enabled;
  final int position;
  final DateTime createdAt;
  final DateTime updatedAt;
}

/// Artifact record together with ownership after variant inheritance.
class ResolvedModelArtifact {
  const ResolvedModelArtifact({
    required this.record,
    required this.ownerModelId,
    required this.inherited,
    this.ownerSuffix,
    this.storageKey,
  });

  final ModelArtifactRecord record;
  final String ownerModelId;
  final bool inherited;
  final String? ownerSuffix;

  /// Stable directory key used by artifact storage; the owner's external id.
  final String? storageKey;
}

class ModelSettingsRecord {
  const ModelSettingsRecord({
    required this.id,
    required this.modelId,
    required this.updatedAt,
    this.options = const AiGenerationOptions(),
    this.overrides = const {},
    this.maxThinkingTokens,
    this.thinkingConfig = const {},
    this.version = 1,
  });

  final String id;
  final String modelId;
  final AiGenerationOptions options;
  final Map<String, dynamic> overrides;
  final int? maxThinkingTokens;
  final Map<String, dynamic> thinkingConfig;
  final int version;
  final DateTime updatedAt;
}

String validateModelSuffix(String value) {
  final suffix = value.trim();
  if (suffix.isEmpty) throw const FormatException('Variant suffix is required');
  if (!RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(suffix) ||
      suffix == '.' ||
      suffix == '..') {
    throw const FormatException(
      'Variant suffix must be a single path-safe segment',
    );
  }
  if (suffix.contains(RegExp(r'[\u0000-\u001f]'))) {
    throw const FormatException(
      'Variant suffix contains unsupported characters',
    );
  }
  return suffix;
}

String modelRecordId(String providerId, String externalModelId) =>
    '$providerId:$externalModelId';

String modelSettingsRecordId(String modelId) => '$modelId:settings';

String? artifactFormatFor(String? path) {
  if (path == null) return null;
  final normalized = path.trim().toLowerCase();
  final dot = normalized.lastIndexOf('.');
  if (dot < 0 || dot == normalized.length - 1) return null;
  return normalized.substring(dot + 1);
}

/// Supported tasks declared by a model, canonicalised and de-duplicated.
List<TaskDeclaration> normaliseTaskDeclarations(
  Iterable<TaskDeclaration> declarations,
) {
  final byTask = <AiTaskId, TaskDeclaration>{};
  for (final declaration in declarations) {
    final current = byTask[declaration.task];
    if (current == null ||
        declaration.confidence.index < current.confidence.index) {
      byTask[declaration.task] = declaration;
    }
  }
  return List.unmodifiable(byTask.values);
}

Map<String, dynamic> taskDeclarationToJson(TaskDeclaration declaration) => {
  'taskId': declaration.task.id,
  'confidence': declaration.confidence.name,
  'source': declaration.source.name,
  'upstreamValue': declaration.upstreamValue,
  'refreshedAt': declaration.refreshedAt?.toIso8601String(),
};

TaskDeclaration? taskDeclarationFromJson(Map<String, dynamic> json) {
  final task = AiTaskId.fromId(json['taskId'] as String?);
  if (task == null) return null;
  final confidence = TaskMetadataConfidence.values.firstWhere(
    (item) => item.name == json['confidence'],
    orElse: () => TaskMetadataConfidence.unknown,
  );
  final source = TaskMetadataSource.values.firstWhere(
    (item) => item.name == json['source'],
    orElse: () => TaskMetadataSource.provider,
  );
  return TaskDeclaration(
    task: task,
    confidence: confidence,
    source: source,
    upstreamValue: json['upstreamValue'] as String?,
    refreshedAt: DateTime.tryParse('${json['refreshedAt']}'),
  );
}
