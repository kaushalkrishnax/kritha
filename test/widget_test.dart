import 'package:drift/native.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kritha/app.dart';
import 'package:kritha/core/providers.dart';
import 'package:kritha/data/app_database.dart';
import 'package:kritha/features/chat/widgets/message_list.dart';
import 'package:kritha/services/runtime_probe.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  Widget buildApp() {
    const runtime = RuntimeStatus(
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
      ],
      child: const KrithaApp(),
    );
  }

  testWidgets('renders the seeded conversation and navigates', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    // History opens at the newest turn; scroll back to the seeded opener.
    await tester.scrollUntilVisible(
      find.textContaining('Good morning, Kaushal'),
      -300,
      scrollable: find
          .descendant(
            of: find.byType(MessageList),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Good morning, Kaushal'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(await database.countMessages(), 5);

    await tester.tap(find.byTooltip('Sessions'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Runtime & packages'), findsOneWidget);
    expect(find.text('v1.13.8'), findsWidgets);
    expect(find.textContaining('Kritha Flutter stack'), findsOneWidget);

    // The back control is exactly the 44px circle, with no IconButton padding
    // shrinking the ripple inside the visible surface.
    expect(tester.getSize(find.byTooltip('Back')), const Size(44, 44));
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Runtime & packages'), findsNothing);
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
    expect(await database.countSessions(), 1);

    await tester.enterText(find.byType(TextField), 'Plan a small Flutter demo');
    await tester.pump();
    await tester.tap(find.byTooltip('Send message'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    final sessions = await database.allSessions();
    expect(sessions, hasLength(2));
    expect(
      sessions.any((session) => session.title == 'Plan a small Flutter demo'),
      isTrue,
    );

    await tester.tap(find.byTooltip('Sessions'));
    await tester.pumpAndSettle();
    expect(
      find.text('Plan a small Flutter demo').hitTestable(),
      findsOneWidget,
    );
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

    expect(await database.countMessages(), 7);
    final messages = await database.allMessages();
    expect(messages[5].text, 'How big is the APK?');
    expect(messages[6].role.name, 'assistant');
  });
}
