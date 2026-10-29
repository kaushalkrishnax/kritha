import 'package:drift/native.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kritha/app.dart';
import 'package:kritha/core/providers.dart';
import 'package:kritha/data/app_database.dart';
import 'package:kritha/features/chat/widgets/chat_sidebar.dart';
import 'package:kritha/features/intelligence/inference_provider.dart';
import 'package:kritha/features/intelligence/model_configuration.dart';
import 'package:kritha/features/intelligence/providers.dart';
import 'package:kritha/features/models/active/active_models.dart';
import 'package:kritha/services/runtime_probe.dart';

import 'support/fake_inference.dart';
import 'support/fake_workspace.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  Widget buildApp({InferenceProvider? inference}) {
    const runtime = RuntimeStatus(
      liteRtLmReady: true,
      sherpaVersion: '1.13.8',
      onnxRuntimeVersion: '1.24.1',
      sqliteVersion: '3.51.0',
      secureStorageReady: true,
      preferencesReady: true,
      microphone: 'granted',
      recorderReady: true,
      audioPlayerReady: true,
      dioBaseUrl: 'https://api.kritha.app/v1',
      documentsPath: '/data/user/0/com.kritha.app/app_flutter',
    );

    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        runtimeStatusProvider.overrideWith((ref) async => runtime),
        modelConfigStoreProvider.overrideWithValue(
          InMemoryModelConfigStore('/models/test.litertlm'),
        ),
        activeModelStoreProvider.overrideWithValue(InMemoryActiveModelStore()),
        recentModelStoreProvider.overrideWithValue(InMemoryRecentModelStore()),
        inferenceProvidersProvider.overrideWithValue([
          inference ?? FakeInferenceProvider(),
        ]),
      ],
      child: const KrithaApp(),
    );
  }

  testWidgets('a fresh install starts with an empty history', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text('Start a new chat'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(await database.countMessages(), 0);
    expect(await database.countSessions(), 0);

    await tester.tap(find.byTooltip('Sessions'));
    await tester.pumpAndSettle();
    expect(find.text('No conversations yet'), findsOneWidget);

    await tester.tap(find.byTooltip('Account menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('THEME'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('v1.13.8'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('v1.13.8'), findsWidgets);

    // The back control is exactly the 44px circle, with no IconButton padding
    // shrinking the ripple inside the visible surface.
    expect(tester.getSize(find.byTooltip('Back')), const Size(44, 44));
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('THEME'), findsNothing);
  });

  testWidgets('new chat stays unsaved until the first prompt', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Sessions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New chat'));
    await tester.pumpAndSettle();

    expect(find.text('Start a new chat'), findsOneWidget);
    expect(await database.countSessions(), 0);

    await tester.enterText(find.byType(TextField), 'Plan a small Flutter demo');
    await tester.pump();
    await tester.tap(find.byTooltip('Send message'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    final sessions = await database.allSessions();
    expect(sessions, hasLength(1));
    expect(
      sessions.any((session) => session.title == 'Plan a small Flutter demo'),
      isTrue,
    );

    await tester.tap(find.byTooltip('Sessions'));
    await tester.pumpAndSettle();
    final sidebarTitle = find.descendant(
      of: find.byType(ChatSidebar),
      matching: find.text('Plan a small Flutter demo'),
    );
    await tester.scrollUntilVisible(
      sidebarTitle,
      100,
      scrollable: find
          .descendant(
            of: find.byType(ChatSidebar),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(sidebarTitle.hitTestable(), findsOneWidget);
  });

  testWidgets('sending a message persists the user turn and a reply', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'How big is the APK?');
    await tester.pump();
    await tester.tap(find.byTooltip('Send message'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(await database.countMessages(), 2);
    final messages = await database.allMessages();
    expect(messages[0].text, 'How big is the APK?');
    expect(messages[1].role.name, 'assistant');
  });

  testWidgets('streamed output is shown and can be stopped', (tester) async {
    final manual = ManualInferenceProvider();
    await tester.pumpWidget(buildApp(inference: manual));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Stream a reply');
    await tester.pump();
    await tester.tap(find.byTooltip('Send message'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Thinking…'), findsOneWidget);
    expect(find.byTooltip('Stop response'), findsOneWidget);

    manual.emit('Partial answer');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('Partial answer'), findsOneWidget);

    await tester.tap(find.byTooltip('Stop response'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byTooltip('Stop response'), findsNothing);
    expect(find.textContaining('Partial answer'), findsNothing);
    expect(manual.cancelled, isTrue);
    expect(await database.countMessages(), 1);
    final messages = await database.allMessages();
    expect(messages.last.role.name, 'user');
  });
}
