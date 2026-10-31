import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import '../models/chat_attachment.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../models/model_configuration_record.dart';

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

/// A saved local model configuration.
///
/// Only wizard-owned configuration data is stored; pre-check results are
/// re-evaluated on every open and never persisted.
@DataClassName('ModelConfigurationRow')
class ModelConfigurations extends Table {
  TextColumn get id => text()();
  TextColumn get repositoryId => text()();
  TextColumn get displayName => text()();
  TextColumn get runtimeId => text()();
  TextColumn get branch => text()();
  TextColumn get commitSha => text().nullable()();
  TextColumn get rootPath => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ModelConfigurationArtifactRow')
class ModelConfigurationArtifacts extends Table {
  TextColumn get id => text()();
  TextColumn get configurationId => text()();
  TextColumn get kind => text()();
  TextColumn get sourceType => text()();
  TextColumn get repositoryPath => text().nullable()();
  TextColumn get deviceSourcePath => text().nullable()();
  TextColumn get targetPath => text()();
  IntColumn get sizeBytes => integer().nullable()();
  BoolColumn get selected => boolean().withDefault(const Constant(true))();
  BoolColumn get downloaded => boolean().withDefault(const Constant(false))();
  IntColumn get position => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    ChatSessions,
    ChatEntries,
    ModelConfigurations,
    ModelConfigurationArtifacts,
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
  int get schemaVersion => 4;

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
      if (from < 4) {
        await migrator.createTable(modelConfigurations);
        await migrator.createTable(modelConfigurationArtifacts);
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

  /// Removes turns at or after [from]. Timestamp precision is second-level, so
  /// prompt editing uses [deleteMessagesFromId] instead.
  Future<void> deleteMessagesFrom(String sessionId, DateTime from) {
    return (delete(chatEntries)..where(
          (row) =>
              row.sessionId.equals(sessionId) &
              row.createdAt.isBiggerOrEqualValue(from),
        ))
        .go();
  }

  /// Deletes [messageId] and every later turn without relying on timestamp
  /// uniqueness: Drift stores date times with second precision.
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

  /// Seeds the fixture conversation together with its owning session. Existing
  /// installations are left alone.
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

  /// Links messages written before schema v3 to a session. Returns the session
  /// id that now owns them, or null when there is nothing to adopt.
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

  /// Removes every conversation and message. Used by the settings reset.
  Future<void> resetAll() async {
    await transaction(() async {
      await delete(chatEntries).go();
      await delete(chatSessions).go();
    });
  }

  /// Inserts or replaces one saved configuration together with its artifacts.
  /// Replacing a configuration rewrites its artifact rows, never the shared
  /// rows of another configuration.
  Future<void> saveModelConfiguration(ConfiguredModel model) async {
    await transaction(() async {
      await into(modelConfigurations).insertOnConflictUpdate(
        ModelConfigurationsCompanion.insert(
          id: model.id,
          repositoryId: model.repositoryId,
          displayName: model.displayName,
          runtimeId: model.runtimeId,
          branch: model.branch,
          commitSha: Value(model.commitSha),
          rootPath: model.rootPath,
          createdAt: model.createdAt,
          updatedAt: model.updatedAt,
        ),
      );
      await (delete(
        modelConfigurationArtifacts,
      )..where((row) => row.configurationId.equals(model.id))).go();
      if (model.artifacts.isEmpty) return;
      await batch((batch) {
        batch.insertAll(modelConfigurationArtifacts, [
          for (final artifact in model.artifacts)
            ModelConfigurationArtifactsCompanion.insert(
              id: artifact.id,
              configurationId: model.id,
              kind: artifact.kind,
              sourceType: artifact.sourceType,
              repositoryPath: Value(artifact.repositoryPath),
              deviceSourcePath: Value(artifact.deviceSourcePath),
              targetPath: artifact.targetPath,
              sizeBytes: Value(artifact.sizeBytes),
              selected: Value(artifact.selected),
              downloaded: Value(artifact.downloaded),
              position: Value(artifact.position),
            ),
        ]);
      });
    });
  }

  /// Every saved configuration, newest first, with its artifacts in order.
  Future<List<ConfiguredModel>> configuredModels() async {
    final rows = await (select(
      modelConfigurations,
    )..orderBy([(row) => OrderingTerm.desc(row.updatedAt)])).get();
    if (rows.isEmpty) return const [];
    final artifacts = await _artifactRows();
    return [
      for (final row in rows)
        _mapConfiguredModel(row, artifacts[row.id] ?? const []),
    ];
  }

  Future<ConfiguredModel?> configuredModelById(String id) async {
    final row = await (select(
      modelConfigurations,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    final artifacts = await _artifactRows(configurationId: id);
    return _mapConfiguredModel(row, artifacts[id] ?? const []);
  }

  /// Deletes the configuration row and the artifact rows it owns. The caller
  /// owns the files on disk.
  Future<void> deleteModelConfiguration(String id) async {
    await transaction(() async {
      await (delete(
        modelConfigurationArtifacts,
      )..where((row) => row.configurationId.equals(id))).go();
      await (delete(
        modelConfigurations,
      )..where((row) => row.id.equals(id))).go();
    });
  }

  Future<Map<String, List<ConfiguredModelArtifact>>> _artifactRows({
    String? configurationId,
  }) async {
    final query = select(modelConfigurationArtifacts)
      ..orderBy([
        (row) => OrderingTerm.asc(row.position),
        (row) => OrderingTerm.asc(row.id),
      ]);
    if (configurationId != null) {
      query.where((row) => row.configurationId.equals(configurationId));
    }
    final rows = await query.get();
    final grouped = <String, List<ConfiguredModelArtifact>>{};
    for (final row in rows) {
      grouped
          .putIfAbsent(row.configurationId, () => [])
          .add(_mapConfiguredArtifact(row));
    }
    return grouped;
  }

  ConfiguredModel _mapConfiguredModel(
    ModelConfigurationRow row,
    List<ConfiguredModelArtifact> artifacts,
  ) {
    return ConfiguredModel(
      id: row.id,
      repositoryId: row.repositoryId,
      displayName: row.displayName,
      runtimeId: row.runtimeId,
      branch: row.branch,
      commitSha: row.commitSha,
      rootPath: row.rootPath,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      artifacts: List.unmodifiable(artifacts),
    );
  }

  ConfiguredModelArtifact _mapConfiguredArtifact(
    ModelConfigurationArtifactRow row,
  ) {
    return ConfiguredModelArtifact(
      id: row.id,
      kind: row.kind,
      sourceType: row.sourceType,
      repositoryPath: row.repositoryPath,
      deviceSourcePath: row.deviceSourcePath,
      targetPath: row.targetPath,
      sizeBytes: row.sizeBytes,
      selected: row.selected,
      downloaded: row.downloaded,
      position: row.position,
    );
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
