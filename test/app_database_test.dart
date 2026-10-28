import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kritha/data/app_database.dart';
import 'package:kritha/data/seed_messages.dart';
import 'package:kritha/models/chat_attachment.dart';
import 'package:kritha/models/chat_message.dart';
import 'package:kritha/models/chat_session.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('seeds the fixture conversation once', () async {
    await database.seedIfEmpty(demoMessages());
    await database.seedIfEmpty(demoMessages());

    expect(await database.countMessages(), 5);
    final stored = await database.allMessages();
    expect(stored.first.id, 'seed-1');
    expect(stored.first.role, ChatRole.assistant);
    expect(stored.last.id, 'seed-5');
  });

  test('saves new turns in timestamp order', () async {
    await database.seedIfEmpty(demoMessages());
    await database.saveMessage(
      ChatMessage(
        id: 'new-user',
        role: ChatRole.user,
        text: 'How large is the APK?',
        createdAt: DateTime(2026, 10, 22, 10),
      ),
    );

    final stored = await database.allMessages();
    expect(stored, hasLength(6));
    expect(stored.last.text, 'How large is the APK?');
    expect(stored.last.role, ChatRole.user);
  });

  test('same-second messages load in a deterministic order', () async {
    final at = DateTime(2026, 10, 22, 10);
    await database.saveSession(
      ChatSession(id: 'tie', title: 'Tie', createdAt: at, updatedAt: at),
    );
    await database.saveMessage(
      ChatMessage(
        id: 'tie-b',
        role: ChatRole.assistant,
        text: 'second',
        createdAt: at,
      ),
      sessionId: 'tie',
    );
    await database.saveMessage(
      ChatMessage(
        id: 'tie-a',
        role: ChatRole.user,
        text: 'first',
        createdAt: at,
      ),
      sessionId: 'tie',
    );

    final stored = await database.messagesForSession('tie');
    expect(stored.map((message) => message.id), ['tie-a', 'tie-b']);
  });

  test('deleting from a turn id keeps earlier same-second turns', () async {
    final at = DateTime(2026, 10, 22, 10);
    await database.saveSession(
      ChatSession(id: 's', title: 'S', createdAt: at, updatedAt: at),
    );
    for (final (id, role) in [
      ('s-000000-a', ChatRole.assistant),
      ('s-000001-u', ChatRole.user),
      ('s-000002-a', ChatRole.assistant),
      ('s-000003-u', ChatRole.user),
    ]) {
      await database.saveMessage(
        ChatMessage(id: id, role: role, text: id, createdAt: at),
        sessionId: 's',
      );
    }

    await database.deleteMessagesFromId('s', 's-000001-u');

    final remaining = await database.messagesForSession('s');
    expect(remaining.map((message) => message.id), ['s-000000-a']);
  });

  test('clearHistory removes every row', () async {
    await database.seedIfEmpty(demoMessages());
    await database.clearHistory();

    expect(await database.countMessages(), 0);
  });

  test('attachment metadata survives a save and reload', () async {
    const attachment = ChatAttachment(
      id: 'att-1',
      name: 'diagram.png',
      path: '/tmp/diagram.png',
      sizeBytes: 204_800,
      kind: ChatAttachmentKind.image,
      mimeType: 'image/png',
    );

    await database.saveMessage(
      ChatMessage(
        id: 'with-attachment',
        role: ChatRole.user,
        text: 'What is in this diagram?',
        createdAt: DateTime(2026, 10, 22, 11),
        attachments: const [attachment],
      ),
    );

    final stored = await database.allMessages();
    final message = stored.single;
    expect(message.attachments, hasLength(1));
    expect(message.attachments.single, attachment);
    expect(message.attachments.single.isImage, isTrue);
    expect(message.attachments.single.readableSize, '200 KB');
  });

  test('seeding also creates the owning session', () async {
    await database.seedIfEmpty(demoMessages());

    final sessions = await database.allSessions();
    expect(sessions, hasLength(1));
    expect(sessions.single.id, 'softmax');
    expect(sessions.single.title, 'Softmax & attention');
    expect(sessions.single.pinned, isFalse);
    expect(await database.messagesForSession('softmax'), hasLength(5));
  });

  test('pin, rename, archive and delete round-trip through SQLite', () async {
    await database.seedIfEmpty(demoMessages());
    final session = (await database.allSessions()).single;

    await database.setSessionPinned(session.id, true);
    await database.renameSession(session.id, 'Attention, pinned');
    final pinned = (await database.allSessions()).single;
    expect(pinned.pinned, isTrue);
    expect(pinned.title, 'Attention, pinned');

    await database.setSessionPinned(session.id, false);
    await database.setSessionArchived(session.id, true);
    expect(await database.allSessions(), isEmpty);
    final archived = (await database.allSessions(archived: true)).single;
    expect(archived.archived, isTrue);

    await database.setSessionArchived(session.id, false);
    expect((await database.allSessions()).single.archived, isFalse);

    await database.deleteSession(session.id);
    expect(await database.countSessions(), 0);
    expect(await database.countMessages(), 0);
  });

  test('new sessions sort pinned first and then by recency', () async {
    final now = DateTime(2026, 10, 23, 12);
    await database.saveSession(
      ChatSession(id: 'older', title: 'Older', createdAt: now, updatedAt: now),
    );
    await database.saveSession(
      ChatSession(
        id: 'newer',
        title: 'Newer',
        createdAt: now,
        updatedAt: now.add(const Duration(minutes: 1)),
      ),
    );
    await database.saveSession(
      ChatSession(
        id: 'pinned',
        title: 'Pinned',
        createdAt: now,
        updatedAt: now,
        pinned: true,
      ),
    );

    final ordered = await database.allSessions();
    expect(ordered.map((session) => session.id), ['pinned', 'newer', 'older']);
  });

  test('orphan messages written before schema v3 are adopted', () async {
    await database.saveMessage(
      ChatMessage(
        id: 'legacy-user',
        role: ChatRole.user,
        text: 'Before sessions existed',
        createdAt: DateTime(2026, 10, 20, 9),
      ),
    );
    await database.saveMessage(
      ChatMessage(
        id: 'legacy-reply',
        role: ChatRole.assistant,
        text: 'Still here',
        createdAt: DateTime(2026, 10, 20, 9, 1),
      ),
    );

    final adopted = await database.adoptOrphanMessages();
    expect(adopted, 'earlier-conversation');
    final sessions = await database.allSessions();
    expect(sessions.single.title, 'Earlier conversation');
    expect(
      await database.messagesForSession('earlier-conversation'),
      hasLength(2),
    );
  });
}
