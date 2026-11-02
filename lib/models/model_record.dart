import '../features/intelligence/models/ai_request.dart';
import '../features/intelligence/models/task_registry.dart';

class ModelRecord {
  const ModelRecord({
    required this.id,
    required this.sourceId,
    required this.externalModelId,
    required this.displayName,
    required this.createdAt,
    required this.updatedAt,
    this.parentModelId,
    this.suffix,
    this.publisher,
    this.sourceType = 'unknown',
    this.metadata = const {},
    this.tasks = const [],
  });

  final String id;
  final String sourceId;
  final String externalModelId;
  final String displayName;
  final String? parentModelId;
  final String? suffix;
  final String? publisher;
  final String sourceType;
  final Map<String, dynamic> metadata;
  final List<TaskDeclaration> tasks;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isVariant => parentModelId != null;
  bool get isBaseModel => parentModelId == null;
}

class ModelArtifactRecord {
  const ModelArtifactRecord({
    required this.id,
    required this.modelId,
    required this.externalPath,
    required this.fileName,
    required this.createdAt,
    required this.updatedAt,
    this.kind = 'other',
    this.sourceType = 'repository',
    this.repositoryPath,
    this.deviceSourcePath,
    this.targetPath,
    this.format,
    this.sizeBytes,
    this.isLfs = false,
    this.oid,
    this.revision,
    this.enabled = true,
    this.position = 0,
    this.metadata = const {},
  });

  final String id;
  final String modelId;
  final String externalPath;
  final String fileName;
  final String kind;
  final String sourceType;
  final String? repositoryPath;
  final String? deviceSourcePath;
  final String? targetPath;
  final String? format;
  final int? sizeBytes;
  final bool isLfs;
  final String? oid;
  final String? revision;
  final bool enabled;
  final int position;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;
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

class ActiveModelAssignmentRecord {
  const ActiveModelAssignmentRecord({
    required this.id,
    required this.modelId,
    required this.taskId,
    required this.priority,
    required this.assignmentType,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
    this.metadata = const {},
  });

  final String id;
  final String modelId;
  final String taskId;
  final int priority;
  final String assignmentType;
  final bool enabled;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;
}

String validateModelSuffix(String value) {
  final suffix = value.trim();
  if (suffix.isEmpty) throw const FormatException('Variant suffix is required');
  if (!RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(suffix) ||
      suffix == '.' ||
      suffix == '..') {
    throw const FormatException('Variant suffix must be a single path-safe segment');
  }
  if (suffix.contains(RegExp(r'[\u0000-\u001f]'))) {
    throw const FormatException('Variant suffix contains unsupported characters');
  }
  return suffix;
}

String modelRecordId(String sourceId, String externalModelId) =>
    '$sourceId:$externalModelId';

String modelSettingsRecordId(String modelId) => '$modelId:settings';

String assignmentRecordId(String modelId, String taskId, String assignmentType) =>
    '$modelId:$taskId:$assignmentType';
