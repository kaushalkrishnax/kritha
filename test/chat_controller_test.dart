import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kritha/core/providers.dart';
import 'package:kritha/data/app_database.dart';
import 'package:kritha/features/chat/chat_controller.dart';
import 'package:kritha/models/chat_message.dart';

void main() {
  late AppDatabase database;
  late ProviderContainer container;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(database)],
    );
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  ChatController controller() =>
      container.read(chatControllerProvider.notifier);

  test('a first prompt creates a titled, persisted session', () async {
    final initial = await container.read(chatControllerProvider.future);
    expect(initial.sessions, hasLength(1));
    expect(initial.currentSessionId, 'softmax');
    expect(initial.messages, hasLength(5));

    controller().newChat();
    expect(container.read(chatControllerProvider).value!.isDraft, isTrue);

    await controller().send('Explain the KV cache in one line');

    final state = container.read(chatControllerProvider).value!;
    expect(state.sessions, hasLength(2));
    expect(state.currentSession, isNotNull);
    expect(state.currentSession!.title, 'Explain the KV cache in one line');
    expect(state.messages, hasLength(2));
    expect(state.messages.first.role, ChatRole.user);
    expect(state.messages.last.role, ChatRole.assistant);
    expect(state.currentSessionId, isNot('softmax'));

    final persisted = await database.messagesForSession(
      state.currentSessionId!,
    );
    expect(persisted, hasLength(2));
    expect(persisted.first.text, 'Explain the KV cache in one line');
    expect(await database.countSessions(), 2);
  });

  test('long prompts are trimmed into a readable title', () async {
    await container.read(chatControllerProvider.future);
    controller().newChat();

    await controller().send(
      'Compare the memory bandwidth and latency tradeoffs of paged attention '
      'with a contiguous KV cache in production inference',
    );

    final session = container
        .read(chatControllerProvider)
        .value!
        .currentSession!;
    expect(session.title.endsWith('…'), isTrue);
    expect(session.title.length, lessThanOrEqualTo(49));
  });

  test('editing a prompt restarts the conversation from that turn', () async {
    final initial = await container.read(chatControllerProvider.future);
    final originalTitle = initial.currentSession!.title;
    expect(initial.messages, hasLength(5));

    await controller().send(
      'Edited attention prompt',
      editingMessageId: 'seed-4',
    );

    final state = container.read(chatControllerProvider).value!;
    expect(state.currentSession!.title, originalTitle);
    expect(state.messages, hasLength(5));
    expect(state.messages.any((message) => message.id == 'seed-5'), isFalse);
    expect(state.messages[3].text, 'Edited attention prompt');
    expect(state.messages[3].role, ChatRole.user);
    expect(state.messages[4].role, ChatRole.assistant);

    final persisted = await database.messagesForSession('softmax');
    expect(persisted, hasLength(5));
    expect(persisted.any((message) => message.id == 'seed-5'), isFalse);
    expect(persisted[3].text, 'Edited attention prompt');
  });

  test('pin, rename, archive, restore and delete update the sidebar', () async {
    await container.read(chatControllerProvider.future);
    controller().newChat();
    await controller().send('Pinned session');
    final created = container
        .read(chatControllerProvider)
        .value!
        .sessions
        .firstWhere((session) => session.title == 'Pinned session');

    await controller().togglePinned(created.id);
    final pinned = container.read(chatControllerProvider).value!;
    expect(pinned.sessions.first.id, created.id);
    expect(pinned.sessions.first.pinned, isTrue);

    await controller().renameSession(created.id, 'Renamed session');
    expect(
      container.read(chatControllerProvider).value!.sessions.first.title,
      'Renamed session',
    );

    await controller().archiveSession(created.id);
    final archived = container.read(chatControllerProvider).value!;
    expect(
      archived.sessions.any((session) => session.id == created.id),
      isFalse,
    );
    expect(
      archived.archivedSessions.any((session) => session.id == created.id),
      isTrue,
    );
    // Archiving the open chat falls back to the newest remaining session.
    expect(archived.currentSessionId, 'softmax');

    await controller().restoreSession(created.id);
    final restored = container.read(chatControllerProvider).value!;
    expect(
      restored.sessions.any((session) => session.id == created.id),
      isTrue,
    );
    expect(restored.archivedSessions, isEmpty);

    await controller().selectSession(created.id);
    await controller().deleteSession(created.id);
    final deleted = container.read(chatControllerProvider).value!;
    expect(deleted.sessions, hasLength(1));
    expect(deleted.currentSessionId, 'softmax');
    expect(await database.countMessagesInSession(created.id), 0);
  });
}
