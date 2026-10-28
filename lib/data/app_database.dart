import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import '../models/chat_attachment.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';

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

@DriftDatabase(tables: [ChatSessions, ChatEntries])
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
  int get schemaVersion => 3;

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
