import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import '../models/chat_attachment.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../models/model_record.dart';
import '../features/intelligence/models/ai_request.dart';
import '../features/intelligence/models/task_registry.dart';

part 'app_database.g.dart';

@DataClassName('SessionRow')
class ChatSessions extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ChatEntries extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text().withDefault(const Constant(''))();
  TextColumn get role => text()();
  TextColumn get content => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get attachmentsJson => text().withDefault(const Constant('[]'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Per-action user choices, e.g. suppressed confirmation prompts.
@DataClassName('ActionPreferenceRow')
class ActionPreferences extends Table {
  TextColumn get actionKey => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {actionKey};
}

class Models extends Table {
  TextColumn get id => text()();
  TextColumn get sourceId => text()();
  TextColumn get externalModelId => text()();
  TextColumn get displayName => text()();
  TextColumn get parentModelId => text().nullable()();
  TextColumn get suffix => text().nullable()();
  TextColumn get publisher => text().nullable()();
  TextColumn get sourceType => text().withDefault(const Constant('unknown'))();
  TextColumn get metadataJson => text().withDefault(const Constant('{}'))();
  TextColumn get taskJson => text().withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ModelArtifacts extends Table {
  TextColumn get id => text()();
  TextColumn get modelId => text()();
  TextColumn get externalPath => text()();
  TextColumn get fileName => text()();
  TextColumn get kind => text().withDefault(const Constant('other'))();
  TextColumn get sourceType => text().withDefault(const Constant('repository'))();
  TextColumn get repositoryPath => text().nullable()();
  TextColumn get deviceSourcePath => text().nullable()();
  TextColumn get targetPath => text().nullable()();
  TextColumn get format => text().nullable()();
  IntColumn get sizeBytes => integer().nullable()();
  BoolColumn get isLfs => boolean().withDefault(const Constant(false))();
  TextColumn get oid => text().nullable()();
  TextColumn get revision => text().nullable()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  IntColumn get position => integer().withDefault(const Constant(0))();
  TextColumn get metadataJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ModelSettings extends Table {
  TextColumn get id => text()();
  TextColumn get modelId => text()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get optionsJson => text().withDefault(const Constant('{}'))();
  TextColumn get overridesJson => text().withDefault(const Constant('{}'))();
  IntColumn get maxThinkingTokens => integer().nullable()();
  TextColumn get thinkingConfigJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ActiveModelAssignmentRow')
class ActiveModelAssignments extends Table {
  TextColumn get id => text()();
  TextColumn get modelId => text()();
  TextColumn get taskId => text()();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  TextColumn get assignmentType => text().withDefault(const Constant('single'))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  TextColumn get metadataJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    ChatSessions,
    ChatEntries,
    ActionPreferences,
    Models,
    ModelArtifacts,
    ModelSettings,
    ActiveModelAssignments,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// File-backed database in the app documents directory.
  AppDatabase.open()
    : super(
        LazyDatabase(() async {
          final directory = await getApplicationDocumentsDirectory();
          final file = File('${directory.path}/kritha.sqlite');
          return NativeDatabase.createInBackground(file);
        }),
      );

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(chatEntries, chatEntries.attachmentsJson);
      }
      if (from < 3) {
        await migrator.createTable(chatSessions);
        await migrator.addColumn(chatEntries, chatEntries.sessionId);
      }
      if (from < 5) {
        await migrator.createTable(actionPreferences);
      }
      if (from < 6) {
        await migrator.createTable(models);
        await migrator.createTable(modelArtifacts);
        await migrator.createTable(modelSettings);
        await migrator.createTable(activeModelAssignments);
      }
    },
  );

  Future<List<ChatMessage>> allMessages() async {
    final rows =
        await (select(chatEntries)..orderBy([
              (row) => OrderingTerm.asc(row.createdAt),
              (row) => OrderingTerm.asc(row.id),
            ]))
            .get();
    return [for (final row in rows) _mapMessage(row)];
  }

  Future<List<ChatMessage>> messagesForSession(String sessionId) async {
    final rows =
        await (select(chatEntries)
              ..where((row) => row.sessionId.equals(sessionId))
              ..orderBy([
                (row) => OrderingTerm.asc(row.createdAt),
                (row) => OrderingTerm.asc(row.id),
              ]))
            .get();
    return [for (final row in rows) _mapMessage(row)];
  }

  Future<List<ChatSession>> allSessions({bool archived = false}) async {
    final rows = await (select(
      chatSessions,
    )..where((row) => row.archived.equals(archived))).get();
    final sessions = [for (final row in rows) _mapSession(row)];
    sessions.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return sessions;
  }

  Future<ChatSession?> sessionById(String id) async {
    final row = await (select(
      chatSessions,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    return row == null ? null : _mapSession(row);
  }

  Future<void> saveSession(ChatSession session) {
    return into(chatSessions).insertOnConflictUpdate(
      ChatSessionsCompanion.insert(
        id: session.id,
        title: session.title,
        createdAt: session.createdAt,
        updatedAt: session.updatedAt,
        pinned: Value(session.pinned),
        archived: Value(session.archived),
      ),
    );
  }

  Future<void> renameSession(String id, String title) {
    return (update(chatSessions)..where((row) => row.id.equals(id))).write(
      ChatSessionsCompanion(title: Value(title)),
    );
  }

  Future<void> setSessionPinned(String id, bool pinned) {
    return (update(chatSessions)..where((row) => row.id.equals(id))).write(
      ChatSessionsCompanion(pinned: Value(pinned)),
    );
  }

  Future<void> setSessionArchived(String id, bool archived) {
    return (update(chatSessions)..where((row) => row.id.equals(id))).write(
      ChatSessionsCompanion(archived: Value(archived)),
    );
  }

  Future<void> touchSession(String id, DateTime updatedAt) {
    return (update(chatSessions)..where((row) => row.id.equals(id))).write(
      ChatSessionsCompanion(updatedAt: Value(updatedAt)),
    );
  }

  Future<void> deleteSession(String id) async {
    await transaction(() async {
      await (delete(
        chatEntries,
      )..where((row) => row.sessionId.equals(id))).go();
      await (delete(chatSessions)..where((row) => row.id.equals(id))).go();
    });
  }

  Future<int> countSessions() async {
    final count = chatSessions.id.count();
    final query = selectOnly(chatSessions)..addColumns([count]);
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<int> countMessagesInSession(String sessionId) async {
    final count = chatEntries.id.count();
    final query = selectOnly(chatEntries)
      ..where(chatEntries.sessionId.equals(sessionId))
      ..addColumns([count]);
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<void> saveMessage(ChatMessage message, {String sessionId = ''}) {
    return into(chatEntries).insertOnConflictUpdate(
      ChatEntriesCompanion.insert(
        id: message.id,
        sessionId: Value(sessionId),
        role: message.role.name,
        content: message.text,
        createdAt: message.createdAt,
        attachmentsJson: Value(_encodeAttachments(message.attachments)),
      ),
    );
  }

  /// Removes turns at or after [from]; prompt editing uses [deleteMessagesFromId].
  Future<void> deleteMessagesFrom(String sessionId, DateTime from) {
    return (delete(chatEntries)..where(
          (row) =>
              row.sessionId.equals(sessionId) &
              row.createdAt.isBiggerOrEqualValue(from),
        ))
        .go();
  }

  /// Deletes [messageId] and later turns; avoids second-precision timestamp collisions.
  Future<void> deleteMessagesFromId(String sessionId, String messageId) async {
    await transaction(() async {
      final messages = await messagesForSession(sessionId);
      final index = messages.indexWhere((message) => message.id == messageId);
      if (index < 0) return;
      final ids = [
        for (var i = index; i < messages.length; i++) messages[i].id,
      ];
      await (delete(
            chatEntries,
          )..where((row) => row.sessionId.equals(sessionId) & row.id.isIn(ids)))
          .go();
    });
  }

  Future<int> countMessages() async {
    final count = chatEntries.id.count();
    final query = selectOnly(chatEntries)..addColumns([count]);
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  /// Seeds fixture conversation on fresh installs.
  Future<void> seedIfEmpty(Iterable<ChatMessage> messages) async {
    if (await countMessages() > 0 || await countSessions() > 0) {
      return;
    }
    final list = messages.toList();
    if (list.isEmpty) return;

    const sessionId = 'softmax';
    final session = ChatSession(
      id: sessionId,
      title: 'Softmax & attention',
      createdAt: list.first.createdAt,
      updatedAt: list.last.createdAt,
    );
    await saveSession(session);
    await batch((batch) {
      batch.insertAll(chatEntries, [
        for (final message in list)
          ChatEntriesCompanion.insert(
            id: message.id,
            sessionId: const Value(sessionId),
            role: message.role.name,
            content: message.text,
            createdAt: message.createdAt,
            attachmentsJson: Value(_encodeAttachments(message.attachments)),
          ),
      ]);
    });
  }

  /// Migrates pre-v3 messages to an adopted session.
  Future<String?> adoptOrphanMessages() async {
    final orphans = await (select(
      chatEntries,
    )..where((row) => row.sessionId.equals(''))).get();
    if (orphans.isEmpty) return null;

    final existing = [
      ...await allSessions(archived: true),
      ...await allSessions(),
    ];
    if (existing.isNotEmpty) {
      final target = existing.first.id;
      await (update(chatEntries)..where((row) => row.sessionId.equals('')))
          .write(ChatEntriesCompanion(sessionId: Value(target)));
      return target;
    }

    const sessionId = 'earlier-conversation';
    final session = ChatSession(
      id: sessionId,
      title: 'Earlier conversation',
      createdAt: orphans.first.createdAt,
      updatedAt: orphans.last.createdAt,
    );
    await saveSession(session);
    await (update(chatEntries)..where((row) => row.sessionId.equals(''))).write(
      ChatEntriesCompanion(sessionId: const Value(sessionId)),
    );
    return sessionId;
  }

  Future<void> clearHistory() => delete(chatEntries).go();

  /// Removes every conversation and message for settings reset.
  Future<void> resetAll() async {
    await transaction(() async {
      await delete(chatEntries).go();
      await delete(chatSessions).go();
    });
  }

  Future<List<ModelRecord>> allModelRecords() async {
    final rows = await (select(models)
          ..orderBy([(row) => OrderingTerm.asc(row.displayName)]))
        .get();
    return [for (final row in rows) _mapModelRecord(row)];
  }

  Future<ModelRecord?> modelRecordById(String id) async {
    final row = await (select(models)..where((item) => item.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _mapModelRecord(row);
  }

  Future<void> deleteArtifactsForModel(String modelId) async {
    await (delete(modelArtifacts)..where((row) => row.modelId.equals(modelId))).go();
  }

  Future<void> deleteModelRecord(String id) async {
    await transaction(() async {
      await deleteArtifactsForModel(id);
      await (delete(modelSettings)..where((row) => row.modelId.equals(id))).go();
      await (delete(activeModelAssignments)..where((row) => row.modelId.equals(id))).go();
      await (delete(models)..where((row) => row.id.equals(id))).go();
    });
  }

  Future<void> updateModelSuffix(String modelId, String suffix) async {
    final model = await modelRecordById(modelId);
    if (model == null || model.parentModelId == null) {
      throw const FormatException('Only a variant model can have a suffix');
    }
    final validated = validateModelSuffix(suffix);
    final siblings = await childModelsOf(model.parentModelId!);
    if (siblings.any((item) => item.id != modelId && item.suffix == validated)) {
      throw const FormatException('Variant suffix already exists for this model');
    }
    await (update(models)..where((row) => row.id.equals(modelId))).write(
      ModelsCompanion(suffix: Value(validated), updatedAt: Value(DateTime.now())),
    );
  }

  Future<List<ModelRecord>> childModelsOf(String parentModelId) async {
    final rows = await (select(models)
          ..where((row) => row.parentModelId.equals(parentModelId))
          ..orderBy([(row) => OrderingTerm.asc(row.suffix)]))
        .get();
    return [for (final row in rows) _mapModelRecord(row)];
  }

  Future<ModelRecord?> baseModelFor(String modelId) async {
    final model = await modelRecordById(modelId);
    if (model == null) return null;
    return model.parentModelId == null
        ? model
        : modelRecordById(model.parentModelId!);
  }

  Future<List<ModelArtifactRecord>> artifactsForModel(String modelId) async {
    final model = await modelRecordById(modelId);
    if (model == null) return const [];
    final rows = await (select(modelArtifacts)
          ..where((row) => row.modelId.equals(modelId))
          ..orderBy([
            (row) => OrderingTerm.asc(row.position),
            (row) => OrderingTerm.asc(row.fileName),
          ]))
        .get();
    final own = [for (final row in rows) _mapModelArtifact(row)];
    if (model.parentModelId == null) return own;
    final inherited = await artifactsForModel(model.parentModelId!);
    return [...inherited, ...own];
  }

  Future<ModelSettingsRecord?> modelSettingsFor(String modelId) async {
    final row = await (select(modelSettings)
          ..where((item) => item.modelId.equals(modelId)))
        .getSingleOrNull();
    return row == null ? null : _mapModelSettings(row);
  }

  Future<List<ActiveModelAssignmentRecord>> activeModelAssignmentsForTask(
    String taskId,
  ) async {
    final rows = await (select(activeModelAssignments)
          ..where((row) => row.taskId.equals(taskId) & row.enabled.equals(true))
          ..orderBy([(row) => OrderingTerm.desc(row.priority)]))
        .get();
    return [for (final row in rows) _mapAssignment(row)];
  }

  Future<List<ActiveModelAssignmentRecord>> allActiveModelAssignments() async {
    final rows = await (select(activeModelAssignments)
          ..where((row) => row.enabled.equals(true))
          ..orderBy([(row) => OrderingTerm.desc(row.priority)]))
        .get();
    return [for (final row in rows) _mapAssignment(row)];
  }

  Future<void> saveModelRecord(ModelRecord model) async {
    if (model.isVariant) {
      final parent = await modelRecordById(model.parentModelId!);
      if (parent == null || parent.parentModelId != null) {
        throw const FormatException('A variant must reference a base model');
      }
      if (parent.sourceId != model.sourceId ||
          parent.externalModelId != model.externalModelId) {
        throw const FormatException(
          'A variant must retain its base model source and external ID',
        );
      }
      validateModelSuffix(model.suffix!);
      final siblings = await childModelsOf(parent.id);
      if (siblings.any((item) => item.suffix == model.suffix && item.id != model.id)) {
        throw const FormatException('Variant suffix already exists for this model');
      }
    } else if (model.suffix != null || model.parentModelId != null) {
      throw const FormatException('Base models cannot have a parent or suffix');
    }
    await into(models).insertOnConflictUpdate(
      ModelsCompanion.insert(
        id: model.id,
        sourceId: model.sourceId,
        externalModelId: model.externalModelId,
        displayName: model.displayName,
        parentModelId: Value(model.parentModelId),
        suffix: Value(model.suffix),
        publisher: Value(model.publisher),
        sourceType: Value(model.sourceType),
        metadataJson: Value(jsonEncode(model.metadata)),
        taskJson: Value(jsonEncode([
          for (final declaration in model.tasks)
            {
              'taskId': declaration.task.id,
              'confidence': declaration.confidence.name,
              'source': declaration.source.name,
              'upstreamValue': declaration.upstreamValue,
              'refreshedAt': declaration.refreshedAt?.toIso8601String(),
            },
        ])),
        createdAt: model.createdAt,
        updatedAt: model.updatedAt,
      ),
    );
  }

  Future<void> saveModelArtifact(ModelArtifactRecord artifact) async {
    await into(modelArtifacts).insertOnConflictUpdate(
      ModelArtifactsCompanion.insert(
        id: artifact.id,
        modelId: artifact.modelId,
        externalPath: artifact.externalPath,
        fileName: artifact.fileName,
        kind: Value(artifact.kind),
        sourceType: Value(artifact.sourceType),
        repositoryPath: Value(artifact.repositoryPath),
        deviceSourcePath: Value(artifact.deviceSourcePath),
        targetPath: Value(artifact.targetPath),
        format: Value(artifact.format),
        sizeBytes: Value(artifact.sizeBytes),
        isLfs: Value(artifact.isLfs),
        oid: Value(artifact.oid),
        revision: Value(artifact.revision),
        enabled: Value(artifact.enabled),
        position: Value(artifact.position),
        metadataJson: Value(jsonEncode(artifact.metadata)),
        createdAt: artifact.createdAt,
        updatedAt: artifact.updatedAt,
      ),
    );
  }

  Future<void> saveModelInferenceSettings(
    ModelSettingsRecord settings,
  ) async {
    await into(modelSettings).insertOnConflictUpdate(
      ModelSettingsCompanion.insert(
        id: settings.id,
        modelId: settings.modelId,
        version: Value(settings.version),
        optionsJson: Value(jsonEncode(settings.options.toJson())),
        overridesJson: Value(jsonEncode(settings.overrides)),
        maxThinkingTokens: Value(settings.maxThinkingTokens),
        thinkingConfigJson: Value(jsonEncode(settings.thinkingConfig)),
        updatedAt: settings.updatedAt,
      ),
    );
  }

  Future<void> saveActiveModelAssignment(
    ActiveModelAssignmentRecord assignment,
  ) async {
    await into(activeModelAssignments).insertOnConflictUpdate(
      ActiveModelAssignmentsCompanion.insert(
        id: assignment.id,
        modelId: assignment.modelId,
        taskId: assignment.taskId,
        priority: Value(assignment.priority),
        assignmentType: Value(assignment.assignmentType),
        enabled: Value(assignment.enabled),
        metadataJson: Value(jsonEncode(assignment.metadata)),
        createdAt: assignment.createdAt,
        updatedAt: assignment.updatedAt,
      ),
    );
  }

  /// Row-per-preference store so new actions need no schema change.
  Future<String?> actionPreference(String actionKey) async {
    final row = await (select(
      actionPreferences,
    )..where((row) => row.actionKey.equals(actionKey))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setActionPreference(String actionKey, String value) async {
    await into(actionPreferences).insertOnConflictUpdate(
      ActionPreferencesCompanion.insert(
        actionKey: actionKey,
        value: value,
        updatedAt: DateTime.now(),
      ),
    );
  }

  ModelRecord _mapModelRecord(Model row) {
    final rawTasks = _decodeList(row.taskJson);
    return ModelRecord(
      id: row.id,
      sourceId: row.sourceId,
      externalModelId: row.externalModelId,
      displayName: row.displayName,
      parentModelId: row.parentModelId,
      suffix: row.suffix,
      publisher: row.publisher,
      sourceType: row.sourceType,
      metadata: _decodeMap(row.metadataJson),
      tasks: _decodeTaskDeclarations(rawTasks),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  ModelArtifactRecord _mapModelArtifact(ModelArtifact row) => ModelArtifactRecord(
    id: row.id,
    modelId: row.modelId,
    externalPath: row.externalPath,
    fileName: row.fileName,
    kind: row.kind,
    sourceType: row.sourceType,
    repositoryPath: row.repositoryPath,
    deviceSourcePath: row.deviceSourcePath,
    targetPath: row.targetPath,
    format: row.format,
    sizeBytes: row.sizeBytes,
    isLfs: row.isLfs,
    oid: row.oid,
    revision: row.revision,
    enabled: row.enabled,
    position: row.position,
    metadata: _decodeMap(row.metadataJson),
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );

  ModelSettingsRecord _mapModelSettings(ModelSetting row) => ModelSettingsRecord(
    id: row.id,
    modelId: row.modelId,
    version: row.version,
    options: AiGenerationOptions.fromJson(_decodeMap(row.optionsJson)),
    overrides: _decodeMap(row.overridesJson),
    maxThinkingTokens: row.maxThinkingTokens,
    thinkingConfig: _decodeMap(row.thinkingConfigJson),
    updatedAt: row.updatedAt,
  );

  ActiveModelAssignmentRecord _mapAssignment(ActiveModelAssignmentRow row) =>
      ActiveModelAssignmentRecord(
        id: row.id,
        modelId: row.modelId,
        taskId: row.taskId,
        priority: row.priority,
        assignmentType: row.assignmentType,
        enabled: row.enabled,
        metadata: _decodeMap(row.metadataJson),
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      );

  TaskDeclaration? _decodeTaskDeclaration(Map<String, dynamic> json) {
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

  List<TaskDeclaration> _decodeTaskDeclarations(List<dynamic> raw) {
    final declarations = <TaskDeclaration>[];
    for (final item in raw) {
      if (item is! Map<String, dynamic>) continue;
      final declaration = _decodeTaskDeclaration(item);
      if (declaration != null) declarations.add(declaration);
    }
    return declarations;
  }

  Map<String, dynamic> _decodeMap(String raw) {
    try {
      final value = jsonDecode(raw);
      return value is Map
          ? {for (final entry in value.entries) '${entry.key}': entry.value}
          : <String, dynamic>{};
    } on Object {
      return <String, dynamic>{};
    }
  }

  List<dynamic> _decodeList(String raw) {
    try {
      final value = jsonDecode(raw);
      return value is List ? value : const [];
    } on Object {
      return const [];
    }
  }

  ChatMessage _mapMessage(ChatEntry row) {
    return ChatMessage(
      id: row.id,
      role: row.role == ChatRole.user.name ? ChatRole.user : ChatRole.assistant,
      text: row.content,
      createdAt: row.createdAt,
      attachments: _decodeAttachments(row.attachmentsJson),
    );
  }

  ChatSession _mapSession(SessionRow row) {
    return ChatSession(
      id: row.id,
      title: row.title,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      pinned: row.pinned,
      archived: row.archived,
    );
  }

  String _encodeAttachments(List<ChatAttachment> attachments) {
    if (attachments.isEmpty) return '[]';
    return jsonEncode([for (final item in attachments) item.toJson()]);
  }

  List<ChatAttachment> _decodeAttachments(String raw) {
    if (raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (item is Map<String, dynamic>) ChatAttachment.fromJson(item),
      ];
    } on FormatException {
      return const [];
    }
  }
}
