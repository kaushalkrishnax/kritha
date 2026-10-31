import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kritha/core/providers.dart';
import 'package:kritha/data/app_database.dart';
import 'package:kritha/features/chat/chat_controller.dart';
import 'package:kritha/features/intelligence/inference_provider.dart';
import 'package:kritha/features/intelligence/intelligence_exception.dart';
import 'package:kritha/features/intelligence/model_configuration.dart';
import 'package:kritha/features/intelligence/models/ai_request.dart';
import 'package:kritha/features/intelligence/providers.dart';
import 'package:kritha/features/intelligence/runtime_ids.dart';
import 'package:kritha/features/models/active/active_models.dart';
import 'package:kritha/features/models/catalogue/catalogue_model.dart';
import 'package:kritha/features/providers/provider_stores.dart';
import 'package:kritha/features/providers/providers_controller.dart';
import 'package:kritha/models/chat_attachment.dart';
import 'package:kritha/models/chat_message.dart';
import 'package:kritha/models/chat_session.dart';

import '../support/fake_inference.dart';
import '../support/fake_workspace.dart';
import '../support/seed_fixture.dart';

void main() {
  late AppDatabase database;
  late ProviderContainer container;
  late FakeInferenceProvider provider;
  late InferenceProvider activeProvider;
  var containerDisposed = false;

  ProviderContainer buildContainer() {
    return ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        modelConfigStoreProvider.overrideWithValue(
          InMemoryModelConfigStore('/models/fake.litertlm'),
        ),
        activeModelStoreProvider.overrideWithValue(InMemoryActiveModelStore()),
        recentModelStoreProvider.overrideWithValue(InMemoryRecentModelStore()),
        inferenceProvidersProvider.overrideWith((ref) => [activeProvider]),
      ],
    );
  }

  setUp(() async {
    containerDisposed = false;
    database = AppDatabase(NativeDatabase.memory());
    await database.seedIfEmpty(demoMessages());
    provider = FakeInferenceProvider(chunks: const ['Local ', 'answer.']);
    activeProvider = provider;
    container = buildContainer();
  });

  tearDown(() async {
    if (!containerDisposed) container.dispose();
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
    expect(state.messages.last.text, 'Local answer.');
    expect(state.sending, isFalse);
    expect(state.streamingText, isNull);
    expect(state.failure, isNull);
    expect(state.currentSessionId, isNot('softmax'));

    final persisted = await database.messagesForSession(
      state.currentSessionId!,
    );
    expect(persisted, hasLength(2));
    expect(persisted.first.text, 'Explain the KV cache in one line');
    expect(persisted.last.text, 'Local answer.');
    expect(await database.countSessions(), 2);
  });

  test('a remote active assignment drives chat streaming', () async {
    container.dispose();
    containerDisposed = true;

    final remoteContainer = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        modelConfigStoreProvider.overrideWithValue(InMemoryModelConfigStore()),
        activeModelStoreProvider.overrideWithValue(
          InMemoryActiveModelStore({
            ModelCapability.text: ActiveModelAssignment(
              capability: ModelCapability.text,
              modelId: 'gpt-4o',
              displayName: 'GPT-4o',
              runtimeId: openAiRuntimeId,
              sourceId: 'openai',
              activatedAt: DateTime(2026),
            ),
          }),
        ),
        recentModelStoreProvider.overrideWithValue(InMemoryRecentModelStore()),
        providerSettingsStoreProvider.overrideWithValue(
          InMemoryProviderSettingsStore({
            'openai': const StoredProviderSettings(
              baseUrl: 'https://api.openai.com/v1',
            ),
          }),
        ),
        providerCredentialStoreProvider.overrideWithValue(
          InMemoryProviderCredentialStore({'openai': 'sk-test'}),
        ),
        inferenceHttpClientFactoryProvider.overrideWithValue(
          () => MockClient((request) async {
            return http.Response(
              'data: ${jsonEncode(_openAiStreamChunk('Remote '))}\n\n'
              'data: ${jsonEncode(_openAiStreamChunk('reply'))}\n\n'
              'data: [DONE]\n\n',
              200,
              headers: {'content-type': 'text/event-stream'},
            );
          }),
        ),
      ],
    );
    addTearDown(remoteContainer.dispose);

    await remoteContainer.read(activeModelsProvider.future);
    await remoteContainer.read(providersControllerProvider.future);
    await remoteContainer.read(chatControllerProvider.future);
    remoteContainer.read(chatControllerProvider.notifier).newChat();
    await remoteContainer
        .read(chatControllerProvider.notifier)
        .send('Remote hello');

    final state = remoteContainer.read(chatControllerProvider).value!;
    expect(state.failure, isNull);
    expect(state.messages.last.text, 'Remote reply');
    final persisted = await database.messagesForSession(
      state.currentSessionId!,
    );
    expect(persisted.last.text, 'Remote reply');
  });

  test('persisted history is mapped into the inference request', () async {
    final initial = await container.read(chatControllerProvider.future);

    await controller().send('Follow up');

    final request = provider.lastRequest!;
    expect(request.messages.map((message) => message.text), [
      ...initial.messages.map((message) => message.text),
      'Follow up',
    ]);
    expect(request.messages.last.role, AiRole.user);
    expect(
      request.messages.any((message) => message.role == AiRole.assistant),
      isTrue,
    );
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
    expect(provider.lastRequest!.messages.last.text, 'Edited attention prompt');
    expect(
      provider.lastRequest!.messages.any(
        (message) => message.text == 'And the attention equation behind it?',
      ),
      isFalse,
    );

    final persisted = await database.messagesForSession('softmax');
    expect(persisted, hasLength(5));
    expect(persisted.any((message) => message.id == 'seed-5'), isFalse);
    expect(persisted[3].text, 'Edited attention prompt');
  });

  test(
    'a typed failure keeps the user turn and retry does not duplicate it',
    () async {
      await container.read(chatControllerProvider.future);
      controller().newChat();
      provider.error = const InferenceFailedException(
        'native detail that must not reach the UI',
        providerId: 'fake',
      );

      await controller().send('Try once');

      var state = container.read(chatControllerProvider).value!;
      expect(state.sending, isFalse);
      expect(state.streamingText, isNull);
      expect(state.failure, isNotNull);
      expect(state.failure!.retryable, isTrue);
      expect(state.failure!.message, isNot(contains('native detail')));
      expect(state.messages, hasLength(1));
      expect(state.messages.single.role, ChatRole.user);

      final sessionId = state.currentSessionId!;
      var persisted = await database.messagesForSession(sessionId);
      expect(persisted, hasLength(1));
      expect(persisted.single.role, ChatRole.user);

      provider.error = null;
      await controller().retryReply();

      state = container.read(chatControllerProvider).value!;
      expect(state.failure, isNull);
      expect(state.messages, hasLength(2));
      expect(state.messages.last.role, ChatRole.assistant);
      expect(state.messages.last.text, 'Local answer.');

      persisted = await database.messagesForSession(sessionId);
      expect(persisted, hasLength(2));
      expect(
        persisted.where((message) => message.role == ChatRole.user),
        hasLength(1),
      );
    },
  );

  test(
    'cancellation clears streaming and persists only the user turn',
    () async {
      final manual = ManualInferenceProvider();
      activeProvider = manual;
      await container.read(chatControllerProvider.future);
      controller().newChat();

      final pending = controller().send('Stream this');
      await pumpEventQueue();
      expect(manual.lastRequest, isNotNull);
      expect(manual.isListening, isTrue);

      manual.emit('Partial');
      await pumpEventQueue();

      var state = container.read(chatControllerProvider).value!;
      expect(state.sending, isTrue);
      expect(state.streamingText, 'Partial');

      await controller().cancelReply();
      await pending;

      state = container.read(chatControllerProvider).value!;
      expect(state.sending, isFalse);
      expect(state.streamingText, isNull);
      expect(state.failure, isNull);
      expect(manual.cancelled, isTrue);

      final persisted = await database.messagesForSession(
        state.currentSessionId!,
      );
      expect(persisted, hasLength(1));
      expect(persisted.single.role, ChatRole.user);
    },
  );

  test('text with attachments sends the text and persists the files', () async {
    await container.read(chatControllerProvider.future);
    controller().newChat();

    await controller().send(
      'Describe this',
      attachments: const [
        ChatAttachment(
          id: 'diagram',
          name: 'diagram.png',
          path: '/tmp/diagram.png',
          sizeBytes: 4096,
          kind: ChatAttachmentKind.file,
          mimeType: 'image/png',
        ),
      ],
    );

    final state = container.read(chatControllerProvider).value!;
    expect(state.messages, hasLength(2));
    expect(state.messages.first.attachments, hasLength(1));
    expect(provider.lastRequest!.messages.last.text, 'Describe this');
    expect(
      provider.lastRequest!.messages.last.text,
      isNot(contains('diagram.png')),
    );
  });

  test('attachment-only prompts fail without calling the model', () async {
    await container.read(chatControllerProvider.future);
    controller().newChat();

    await controller().send(
      '',
      attachments: const [
        ChatAttachment(
          id: 'diagram',
          name: 'diagram.png',
          path: '/tmp/diagram.png',
          sizeBytes: 4096,
          kind: ChatAttachmentKind.file,
          mimeType: 'image/png',
        ),
      ],
    );

    final state = container.read(chatControllerProvider).value!;
    expect(state.failure, isNotNull);
    expect(state.failure!.retryable, isFalse);
    expect(state.failure!.message, contains('Attachments'));
    expect(provider.streamCalls, 0);
    expect(state.messages, hasLength(1));

    final persisted = await database.messagesForSession(
      state.currentSessionId!,
    );
    expect(persisted.single.attachments, hasLength(1));
  });

  test('disposing the controller cancels an in-flight stream', () async {
    final manual = ManualInferenceProvider();
    activeProvider = manual;
    await container.read(chatControllerProvider.future);
    controller().newChat();

    final pending = controller().send('Stream this');
    await pumpEventQueue();
    expect(manual.lastRequest, isNotNull);
    expect(manual.isListening, isTrue);

    container.dispose();
    containerDisposed = true;
    await pumpEventQueue();
    await pending;

    expect(manual.cancelled, isTrue);
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

  test(
    'overlapping sends are ignored while the first is in progress',
    () async {
      await container.read(chatControllerProvider.future);
      controller().newChat();

      final first = controller().send('First prompt');
      final second = controller().send('Second prompt');
      await Future.wait([first, second]);

      final state = container.read(chatControllerProvider).value!;
      expect(state.messages, hasLength(2));
      expect(state.messages.first.text, 'First prompt');
      expect(provider.streamCalls, 1);
      expect(await database.countMessagesInSession(state.currentSessionId!), 2);
    },
  );

  test(
    'empty output fails retryably and persists only the user turn',
    () async {
      activeProvider = FakeInferenceProvider(chunks: const []);
      await container.read(chatControllerProvider.future);
      controller().newChat();

      await controller().send('No answer');

      final state = container.read(chatControllerProvider).value!;
      expect(state.failure, isNotNull);
      expect(state.failure!.retryable, isTrue);
      expect(state.messages, hasLength(1));
      expect(state.messages.single.role, ChatRole.user);

      final persisted = await database.messagesForSession(
        state.currentSessionId!,
      );
      expect(persisted, hasLength(1));
      expect(persisted.single.role, ChatRole.user);
    },
  );

  test('a cancellation error still clears generation state', () async {
    final manual = ManualInferenceProvider();
    activeProvider = manual;
    await container.read(chatControllerProvider.future);
    controller().newChat();

    final pending = controller().send('Cancel me');
    await pumpEventQueue();
    manual.emit('Partial');
    await pumpEventQueue();

    manual.throwOnCancel = true;
    await controller().cancelReply();
    await pending;

    final state = container.read(chatControllerProvider).value!;
    expect(state.sending, isFalse);
    expect(state.streamingText, isNull);
    expect(state.failure, isNull);
    expect(manual.cancelled, isTrue);
  });

  test(
    'retry does not duplicate an assistant reply that was already persisted',
    () async {
      await container.read(chatControllerProvider.future);
      controller().newChat();
      provider.error = const InferenceFailedException(
        'native detail',
        providerId: 'fake',
      );

      await controller().send('Try once');
      var state = container.read(chatControllerProvider).value!;
      final sessionId = state.currentSessionId!;
      final user = state.messages.single;
      await database.saveMessage(
        ChatMessage(
          id: 'assistant-persisted',
          role: ChatRole.assistant,
          text: 'Already saved.',
          createdAt: user.createdAt.add(const Duration(seconds: 1)),
        ),
        sessionId: sessionId,
      );

      final calls = provider.streamCalls;
      provider.error = null;
      await controller().retryReply();

      state = container.read(chatControllerProvider).value!;
      expect(provider.streamCalls, calls);
      expect(state.failure, isNull);
      expect(state.messages.last.role, ChatRole.assistant);
      expect(state.messages.last.text, 'Already saved.');
      expect(await database.messagesForSession(sessionId), hasLength(2));
    },
  );

  test('retry uses persisted history without partial output', () async {
    final manual = ManualInferenceProvider();
    activeProvider = manual;
    await container.read(chatControllerProvider.future);
    controller().newChat();

    final pending = controller().send('Stream this');
    await pumpEventQueue();
    manual.emit('Partial');
    await pumpEventQueue();
    await manual.fail(
      const InferenceFailedException('native detail', providerId: 'fake'),
    );
    await pending;

    var state = container.read(chatControllerProvider).value!;
    expect(state.failure, isNotNull);
    expect(state.messages, hasLength(1));

    final retry = controller().retryReply();
    for (var i = 0; i < 20 && manual.streamCalls < 2; i++) {
      await pumpEventQueue();
    }
    expect(manual.streamCalls, 2);
    expect(manual.lastRequest!.messages.map((message) => message.text), [
      'Stream this',
    ]);
    expect(
      manual.lastRequest!.messages.any((message) => message.text == 'Partial'),
      isFalse,
    );

    manual.emit('Recovered');
    await pumpEventQueue();
    await manual.finish();
    await retry;

    state = container.read(chatControllerProvider).value!;
    expect(state.failure, isNull);
    expect(state.messages.last.text, 'Recovered');
    expect(
      await database.messagesForSession(state.currentSessionId!),
      hasLength(2),
    );
  });

  test('partial output is committed only after the stream completes', () async {
    final manual = ManualInferenceProvider();
    activeProvider = manual;
    await container.read(chatControllerProvider.future);
    controller().newChat();

    final pending = controller().send('Stream this');
    await pumpEventQueue();
    manual.emit('Partial');
    await pumpEventQueue();

    var state = container.read(chatControllerProvider).value!;
    expect(state.streamingText, 'Partial');
    expect(state.messages, hasLength(1));
    expect(
      await database.messagesForSession(state.currentSessionId!),
      hasLength(1),
    );

    manual.emit('Partial and final');
    await pumpEventQueue();
    await manual.finish();
    await pending;

    state = container.read(chatControllerProvider).value!;
    expect(state.streamingText, isNull);
    expect(state.messages.last.text, 'Partial and final');
    expect(
      await database.messagesForSession(state.currentSessionId!),
      hasLength(2),
    );
  });

  test('history is isolated and omits empty turns', () async {
    await container.read(chatControllerProvider.future);
    await database.saveMessage(
      ChatMessage(
        id: 'softmax-000005-u',
        role: ChatRole.user,
        text: '',
        createdAt: DateTime(2026, 10, 28, 12),
        attachments: const [
          ChatAttachment(
            id: 'diagram',
            name: 'diagram.png',
            path: '/tmp/diagram.png',
            sizeBytes: 4096,
            kind: ChatAttachmentKind.file,
            mimeType: 'image/png',
          ),
        ],
      ),
      sessionId: 'softmax',
    );

    controller().newChat();
    await controller().send('Session B prompt');
    final requestB = provider.lastRequest!;
    expect(requestB.messages.map((message) => message.text), [
      'Session B prompt',
    ]);
    expect(
      requestB.messages.any((message) => message.role == AiRole.system),
      isFalse,
    );

    await controller().selectSession('softmax');
    await controller().send('Follow up');
    final request = provider.lastRequest!;
    expect(request.messages.any((message) => message.text.isEmpty), isFalse);
    expect(
      request.messages.any((message) => message.text == 'Session B prompt'),
      isFalse,
    );
    expect(request.messages.last.text, 'Follow up');
    expect(request.messages.last.role, AiRole.user);
  });

  test(
    'switching sessions cancels generation and ignores late output',
    () async {
      final manual = ManualInferenceProvider();
      activeProvider = manual;
      await container.read(chatControllerProvider.future);
      controller().newChat();

      final pending = controller().send('Old session');
      await pumpEventQueue();
      manual.emit('Partial');
      await pumpEventQueue();
      final oldId = container
          .read(chatControllerProvider)
          .value!
          .currentSessionId!;

      await controller().selectSession('softmax');
      var state = container.read(chatControllerProvider).value!;
      expect(state.currentSessionId, 'softmax');
      expect(state.sending, isFalse);
      expect(state.streamingText, isNull);

      manual.emit('Late output');
      await pumpEventQueue();
      state = container.read(chatControllerProvider).value!;
      expect(state.streamingText, isNull);
      await pending;
      expect(manual.cancelled, isTrue);

      final persisted = await database.messagesForSession(oldId);
      expect(persisted, hasLength(1));
      expect(persisted.single.role, ChatRole.user);
    },
  );

  test('new chat cancels generation without persisting output', () async {
    final manual = ManualInferenceProvider();
    activeProvider = manual;
    await container.read(chatControllerProvider.future);
    controller().newChat();

    final pending = controller().send('Old session');
    await pumpEventQueue();
    manual.emit('Partial');
    await pumpEventQueue();
    final oldId = container
        .read(chatControllerProvider)
        .value!
        .currentSessionId!;

    controller().newChat();
    await pending;

    final state = container.read(chatControllerProvider).value!;
    expect(state.isDraft, isTrue);
    expect(state.sending, isFalse);
    expect(state.streamingText, isNull);
    expect(manual.cancelled, isTrue);
    final persisted = await database.messagesForSession(oldId);
    expect(persisted, hasLength(1));
    expect(persisted.single.role, ChatRole.user);
  });

  test('archiving the active chat cancels generation', () async {
    final manual = ManualInferenceProvider();
    activeProvider = manual;
    await container.read(chatControllerProvider.future);
    controller().newChat();

    final pending = controller().send('Old session');
    await pumpEventQueue();
    manual.emit('Partial');
    await pumpEventQueue();
    final oldId = container
        .read(chatControllerProvider)
        .value!
        .currentSessionId!;

    await controller().archiveSession(oldId);
    await pending;

    final state = container.read(chatControllerProvider).value!;
    expect(state.currentSessionId, 'softmax');
    expect(state.sending, isFalse);
    expect(manual.cancelled, isTrue);
    expect(
      state.archivedSessions.any((session) => session.id == oldId),
      isTrue,
    );
    final persisted = await database.messagesForSession(oldId);
    expect(persisted, hasLength(1));
    expect(persisted.single.role, ChatRole.user);
  });

  test('deleting the active chat cancels generation', () async {
    final manual = ManualInferenceProvider();
    activeProvider = manual;
    await container.read(chatControllerProvider.future);
    controller().newChat();

    final pending = controller().send('Old session');
    await pumpEventQueue();
    manual.emit('Partial');
    await pumpEventQueue();
    final oldId = container
        .read(chatControllerProvider)
        .value!
        .currentSessionId!;

    await controller().deleteSession(oldId);
    await pending;

    final state = container.read(chatControllerProvider).value!;
    expect(state.currentSessionId, 'softmax');
    expect(state.sending, isFalse);
    expect(manual.cancelled, isTrue);
    expect(await database.countMessagesInSession(oldId), 0);
  });

  test('a prompt queued after cancellation is not dropped', () async {
    final manual = ManualInferenceProvider();
    activeProvider = manual;
    await container.read(chatControllerProvider.future);
    controller().newChat();

    final first = controller().send('First');
    await pumpEventQueue();
    manual.emit('Partial');
    await pumpEventQueue();

    final cancel = controller().cancelReply();
    final second = controller().send('Second');
    await cancel;
    for (var i = 0; i < 20 && manual.streamCalls < 2; i++) {
      await pumpEventQueue();
    }
    expect(manual.streamCalls, 2);
    manual.emit('Second answer');
    await pumpEventQueue();
    await manual.finish();
    await second;
    await first;

    final state = container.read(chatControllerProvider).value!;
    expect(state.sending, isFalse);
    expect(state.streamingText, isNull);
    expect(state.failure, isNull);
    expect(state.messages.map((message) => message.text), [
      'First',
      'Second',
      'Second answer',
    ]);
  });

  test('an unsupported platform is not retryable', () async {
    await container.read(chatControllerProvider.future);
    controller().newChat();
    provider.error = ProviderUnavailableException(
      'No native runtime.',
      providerId: 'fake',
      cause: UnsupportedError('No native runtime.'),
    );

    await controller().send('Try once');

    final state = container.read(chatControllerProvider).value!;
    expect(state.failure, isNotNull);
    expect(state.failure!.retryable, isFalse);
    expect(state.failure!.message, contains('device'));
    expect(state.messages, hasLength(1));
  });

  test('a delete that wins a commit race leaves no orphan reply', () async {
    container.dispose();
    await database.close();
    final delayed = _DelayedDatabase(NativeDatabase.memory());
    delayed.assistantSaveGate = Completer<void>();
    database = delayed;
    activeProvider = provider;
    container = buildContainer();

    await container.read(chatControllerProvider.future);
    controller().newChat();
    final pending = controller().send('Race');

    for (var i = 0; i < 50 && !delayed.assistantSaveStarted; i++) {
      await pumpEventQueue();
    }
    expect(delayed.assistantSaveStarted, isTrue);
    final sessionId = container
        .read(chatControllerProvider)
        .value!
        .currentSessionId!;

    await controller().deleteSession(sessionId);
    delayed.assistantSaveGate!.complete();
    await pending;

    expect(await database.sessionById(sessionId), isNull);
    expect(await database.countMessagesInSession(sessionId), 0);
  });

  test('a stale session selection cannot replace a newer one', () async {
    container.dispose();
    await database.close();
    final delayed = _DelayedDatabase(NativeDatabase.memory());
    database = delayed;
    activeProvider = provider;
    container = buildContainer();

    await container.read(chatControllerProvider.future);
    final at = DateTime(2026, 10, 28, 13);
    await database.saveSession(
      ChatSession(id: 'other', title: 'Other', createdAt: at, updatedAt: at),
    );
    await database.saveMessage(
      ChatMessage(
        id: 'other-000000-u',
        role: ChatRole.user,
        text: 'Other session',
        createdAt: at,
      ),
      sessionId: 'other',
    );
    await controller().selectSession('other');

    delayed.messageGates['softmax'] = Completer<void>();
    final stale = controller().selectSession('softmax');
    controller().newChat();
    await controller().selectSession('other');
    delayed.messageGates.remove('softmax')!.complete();
    await stale;

    final state = container.read(chatControllerProvider).value!;
    expect(state.currentSessionId, 'other');
    expect(state.messages.single.text, 'Other session');
  });

  test('a prompt sent during selection waits for that session', () async {
    container.dispose();
    await database.close();
    final delayed = _DelayedDatabase(NativeDatabase.memory());
    database = delayed;
    activeProvider = provider;
    container = buildContainer();

    await container.read(chatControllerProvider.future);
    final at = DateTime(2026, 10, 28, 14);
    await database.saveSession(
      ChatSession(id: 'other', title: 'Other', createdAt: at, updatedAt: at),
    );
    await database.saveMessage(
      ChatMessage(
        id: 'other-000000-u',
        role: ChatRole.user,
        text: 'Other session',
        createdAt: at,
      ),
      sessionId: 'other',
    );

    delayed.messageGates['other'] = Completer<void>();
    final selection = controller().selectSession('other');
    final send = controller().send('Target other');
    delayed.messageGates.remove('other')!.complete();
    await selection;
    await send;

    final state = container.read(chatControllerProvider).value!;
    expect(state.currentSessionId, 'other');
    expect(state.messages.map((message) => message.text), [
      'Other session',
      'Target other',
      'Local answer.',
    ]);
    expect(provider.lastRequest!.messages.map((message) => message.text), [
      'Other session',
      'Target other',
    ]);
  });

  test('renaming during streaming preserves partial output', () async {
    container.dispose();
    await database.close();
    final delayed = _DelayedDatabase(NativeDatabase.memory());
    database = delayed;
    await database.seedIfEmpty(demoMessages());
    final manual = ManualInferenceProvider();
    activeProvider = manual;
    container = buildContainer();

    await container.read(chatControllerProvider.future);
    final sessionId = container
        .read(chatControllerProvider)
        .value!
        .currentSessionId!;
    final pending = controller().send('Stream this');
    await pumpEventQueue();
    manual.emit('First');
    await pumpEventQueue();

    delayed.allSessionsGate = Completer<void>();
    final rename = controller().renameSession(sessionId, 'Renamed');
    manual.emit('First and second');
    await pumpEventQueue();
    delayed.allSessionsGate!.complete();
    await rename;

    final state = container.read(chatControllerProvider).value!;
    expect(state.streamingText, 'First and second');
    expect(state.currentSession?.title, 'Renamed');
    expect(state.sending, isTrue);

    await controller().cancelReply();
    await pending;
  });
}

Map<String, dynamic> _openAiStreamChunk(String text) => {
  'id': 'chatcmpl-1',
  'object': 'chat.completion.chunk',
  'created': 1,
  'model': 'gpt-4o',
  'choices': [
    {
      'index': 0,
      'delta': {'content': text},
      'finish_reason': null,
    },
  ],
};

class _DelayedDatabase extends AppDatabase {
  _DelayedDatabase(super.executor);

  final Map<String, Completer<void>> messageGates = {};
  Completer<void>? allSessionsGate;
  Completer<void>? assistantSaveGate;
  bool assistantSaveStarted = false;

  @override
  Future<List<ChatMessage>> messagesForSession(String sessionId) async {
    final gate = messageGates[sessionId];
    if (gate != null) await gate.future;
    return super.messagesForSession(sessionId);
  }

  @override
  Future<List<ChatSession>> allSessions({bool archived = false}) async {
    final gate = allSessionsGate;
    if (gate != null && !archived) await gate.future;
    return super.allSessions(archived: archived);
  }

  @override
  Future<void> saveMessage(ChatMessage message, {String sessionId = ''}) async {
    if (message.role == ChatRole.assistant && assistantSaveGate != null) {
      assistantSaveStarted = true;
      await assistantSaveGate!.future;
    }
    return super.saveMessage(message, sessionId: sessionId);
  }
}
