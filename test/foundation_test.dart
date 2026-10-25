import 'package:drift/native.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:kritha/app.dart';
import 'package:kritha/core/providers.dart';
import 'package:kritha/core/responsive.dart';
import 'package:kritha/core/theme.dart';
import 'package:kritha/data/app_database.dart';
import 'package:kritha/features/chat/widgets/composer/composer_controller.dart';
import 'package:kritha/features/chat/widgets/composer/dictation_bar.dart';
import 'package:kritha/features/chat/widgets/composer/normal_composer.dart';
import 'package:kritha/features/chat/widgets/composer/recording_waveform.dart';
import 'package:kritha/features/chat/dictation_controller.dart';
import 'package:kritha/features/chat/widgets/chat_sidebar.dart';
import 'package:kritha/features/chat/widgets/kritha_avatar.dart';
import 'package:kritha/features/chat/widgets/message_list.dart';
import 'package:kritha/models/chat_attachment.dart';
import 'package:kritha/services/runtime_probe.dart';

class _FakeDictationNotifier extends DictationNotifier {
  @override
  DictationState build() => const DictationState(
    phase: DictationPhase.listening,
    elapsed: Duration(seconds: 12),
    levels: [0.2, 0.5, 0.9, 0.4, 0.7, 0.3, 0.8, 0.6, 0.25, 0.55, 0.95, 0.35],
  );
}

const _runtime = RuntimeStatus(
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

void main() {
  group('Kritha design system & responsive tokens', () {
    test('breakpoints use 600 and 840', () {
      expect(KrithaBreakpoints.compact, 600);
      expect(KrithaBreakpoints.medium, 840);

      expect(viewportOf(320), KrithaViewport.compact);
      expect(viewportOf(599), KrithaViewport.compact);
      expect(viewportOf(600), KrithaViewport.medium);
      expect(viewportOf(839), KrithaViewport.medium);
      expect(viewportOf(840), KrithaViewport.wide);
      expect(viewportOf(1440), KrithaViewport.wide);
    });

    test('theme owns DM Sans and the primary text colour', () {
      final theme = buildKrithaTheme();
      expect(theme.textTheme.bodyMedium!.fontFamily, KrithaFonts.dmSans);
      expect(theme.textTheme.bodyLarge!.fontFamily, KrithaFonts.dmSans);
      expect(theme.textTheme.bodyMedium!.color, KrithaColors.textPrimary);
      expect(theme.textTheme.bodyLarge!.color, KrithaColors.textPrimary);
      // Component styles stay free of redundant family/colour declarations.
      expect(KrithaText.body.fontFamily, isNull);
      expect(KrithaText.body.color, isNull);
      expect(KrithaText.message.fontFamily, isNull);
      expect(KrithaText.message.color, isNull);
    });

    test('palette tokens match the React Native theme.ts', () {
      expect(KrithaColors.bgDeepest, const Color(0xFF000000));
      expect(KrithaColors.bgBase, const Color(0xFF0B0D10));
      expect(KrithaColors.bgSurface, const Color(0xFF111419));
      expect(KrithaColors.bgPrimary, const Color(0xFF171A1F));
      expect(KrithaColors.bgSecondary, const Color(0xFF1E2228));
      expect(KrithaColors.bgTertiary, const Color(0xFF262B32));
      expect(KrithaColors.bgQuaternary, const Color(0xFF2E343C));
      expect(KrithaColors.bgCard, const Color(0xFF1B1F24));

      expect(KrithaColors.textPrimary, const Color(0xFFF4F7FA));
      expect(KrithaColors.textSecondary, const Color(0xFFD7DDE5));
      expect(KrithaColors.textMuted, const Color(0xFF9299A3));
      expect(KrithaColors.textDimmed, const Color(0xFF68717D));

      expect(KrithaColors.accentBlue, const Color(0xFF2563EB));
      expect(KrithaColors.accentLightBlue, const Color(0xFF60A5FA));
      expect(KrithaColors.accentCyan, const Color(0xFF22D3EE));
      expect(KrithaColors.accentCyanBg, const Color(0xFF164E63));

      expect(KrithaColors.userBubbleBg, const Color(0xFF21437D));
      expect(KrithaColors.assistantBubbleBg, const Color(0x142563EB));
      expect(KrithaColors.bgScrim, const Color(0x99000000));
    });

    test('typography, radii and dimensions match the source', () {
      expect(KrithaText.size2xs, 12.0);
      expect(KrithaText.sizeXs, 13.0);
      expect(KrithaText.sizeSm, 15.0);
      expect(KrithaText.sizeBase, 17.0);
      expect(KrithaText.sizeMd, 18.0);
      expect(KrithaText.sizeLg, 20.0);
      expect(KrithaText.sizeXl, 22.0);
      expect(KrithaText.size2xl, 26.0);
      expect(KrithaText.size3xl, 30.0);
      expect(KrithaText.lineHeightBase, 26.0);

      expect(KrithaRadius.xs, 4.0);
      expect(KrithaRadius.sm, 8.0);
      expect(KrithaRadius.base, 12.0);
      expect(KrithaRadius.md, 16.0);
      expect(KrithaRadius.lg, 20.0);
      expect(KrithaRadius.xl, 24.0);
      expect(KrithaRadius.xl2, 28.0);
      expect(KrithaRadius.full, 100.0);

      expect(KrithaDimensions.composerCompactHeight, 58.0);
      expect(KrithaDimensions.composerExpandedMinHeight, 116.0);
      expect(KrithaDimensions.headerHeight, 60.0);
      expect(KrithaSpacing.sidebarPadding, 24.0);
      expect(KrithaSpacing.messageGap, 8.0);
    });
  });

  group('chat shell', () {
    late AppDatabase database;

    setUp(() => database = AppDatabase(NativeDatabase.memory()));
    tearDown(() => database.close());

    Future<void> pumpApp(
      WidgetTester tester, {
      Size size = const Size(400, 900),
      EdgeInsets viewInsets = EdgeInsets.zero,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: size, viewInsets: viewInsets),
          child: ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(database),
              runtimeStatusProvider.overrideWith((ref) async => _runtime),
            ],
            child: const KrithaApp(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('theme changes repaint mounted screens without a restart', (
      tester,
    ) async {
      await pumpApp(tester, size: const Size(1280, 800));

      Color chatBackground() => tester
          .widget<ColoredBox>(
            find.byKey(const ValueKey('chat-background'), skipOffstage: false),
          )
          .color;

      expect(chatBackground(), const Color(0xFFF8FAFC));

      await tester.tap(find.byTooltip('Account menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Dark'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(KrithaColors.textPrimary, const Color(0xFFF4F7FA));
      expect(chatBackground(), const Color(0xFF000000));

      await tester.tap(find.text('Light'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(KrithaColors.textPrimary, const Color(0xFF0F172A));
      expect(chatBackground(), const Color(0xFFF8FAFC));

      // Leave the static palette in dark mode for any later test that builds
      // a theme without pumping the app.
      KrithaColors.setLightMode(false);
    });

    testWidgets(
      'compact shell uses a drawer and hides branding in the header',
      (tester) async {
        await pumpApp(tester, size: const Size(375, 812));

        expect(find.byType(MessageList), findsOneWidget);
        expect(find.byTooltip('Sessions'), findsOneWidget);
        expect(find.text('New chat').hitTestable(), findsNothing);

        // The header no longer repeats the Kritha avatar/name over the chat.
        expect(find.text('Kritha').hitTestable(), findsNothing);
        expect(find.byType(KrithaAvatar), findsNothing);

        await tester.tap(find.byTooltip('Sessions'));
        await tester.pumpAndSettle();

        expect(find.text('New chat').hitTestable(), findsOneWidget);
        expect(find.text('Recents').hitTestable(), findsOneWidget);
        expect(find.text('Kaushal Krishna').hitTestable(), findsOneWidget);
        expect(find.text('KK').hitTestable(), findsOneWidget);
        expect(find.textContaining('messages ·').hitTestable(), findsNothing);
        await tester.tap(find.byTooltip('Account menu'));
        await tester.pumpAndSettle();
        expect(find.text('Free'), findsWidgets);
        expect(find.text('Personalization'), findsOneWidget);
        expect(find.text('Profile'), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);
        expect(find.text('Log out'), findsOneWidget);
        final accountMenu = find.byKey(const ValueKey('context-menu-surface'));
        expect(tester.getTopLeft(accountMenu).dx, 0);
        expect(
          tester.getSize(accountMenu).width,
          ChatSidebar.drawerWidthFor(375),
        );
        expect(
          find.descendant(
            of: accountMenu,
            matching: find.text('Kaushal Krishna'),
          ),
          findsNothing,
        );
        expect(
          find.descendant(of: accountMenu, matching: find.text('KK')),
          findsNothing,
        );
        expect(
          find.descendant(of: accountMenu, matching: find.text('Help')),
          findsNothing,
        );
        await tester.tapAt(Offset(350, 400));
        await tester.pumpAndSettle();
        // The drawer closes from the backdrop or an edge swipe; no X button.
        expect(find.byTooltip('Close sidebar'), findsNothing);
        expect(
          tester.getSize(find.byKey(const ValueKey('session-softmax'))).height,
          56,
        );
        expect(
          tester
              .getSize(
                find.ancestor(
                  of: find.text('New chat'),
                  matching: find.byType(InkWell),
                ),
              )
              .height,
          KrithaDimensions.sidebarActionRowHeight,
        );
      },
    );

    testWidgets('header ellipsis opens the per-chat options menu', (
      tester,
    ) async {
      await pumpApp(tester, size: const Size(375, 812));

      expect(find.byTooltip('Runtime'), findsNothing);
      expect(
        find.descendant(
          of: find.byTooltip('Chat options'),
          matching: find.byWidgetPredicate(
            (w) =>
                w is HugeIcon &&
                w.icon == HugeIcons.strokeRoundedEllipsisVertical,
          ),
        ),
        findsOneWidget,
      );

      // The icon's ink surface fills the pill height (no outer dead ring).
      final headerInk = find.descendant(
        of: find.byTooltip('Chat options'),
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(headerInk).height, 48);

      await tester.tap(find.byTooltip('Chat options'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('context-menu-surface')),
        findsOneWidget,
      );
      final title = tester.widget<Text>(find.text('Softmax & attention'));
      expect(title.style?.color, KrithaColors.textMuted);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Pin'), findsOneWidget);
      expect(find.text('Uploaded files'), findsOneWidget);
      expect(find.text('Find in chat'), findsOneWidget);
      expect(find.text('Archive'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      final deleteLabel = tester.widget<Text>(find.text('Delete'));
      expect(deleteLabel.style?.color, KrithaColors.error);
      final deleteRow = find.ancestor(
        of: find.text('Delete'),
        matching: find.byType(InkWell),
      );
      expect(
        tester.widget<InkWell>(deleteRow).overlayColor!.resolve({
          WidgetState.pressed,
        }),
        Color(0x33FF453A),
      );
    });

    testWidgets('medium shell still uses the overlay drawer', (tester) async {
      await pumpApp(tester, size: const Size(768, 1024));

      expect(find.byTooltip('Sessions'), findsOneWidget);
      expect(find.byTooltip('Hide sidebar'), findsNothing);
      expect(find.text('Recents').hitTestable(), findsNothing);
    });

    testWidgets('wide shell docks the sidebar and can hide it', (tester) async {
      await pumpApp(tester, size: const Size(1280, 800));

      expect(find.byTooltip('Collapse sidebar'), findsOneWidget);
      expect(find.text('Recents').hitTestable(), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is SizedBox && widget.width == 300,
        ),
        findsWidgets,
      );

      await tester.tap(find.byTooltip('Account menu'));
      await tester.pumpAndSettle();
      final accountMenu = find.byKey(const ValueKey('context-menu-surface'));
      expect(tester.getTopLeft(accountMenu).dx, 0);
      expect(tester.getSize(accountMenu).width, KrithaDimensions.sidebarWidth);
      await tester.tapAt(const Offset(900, 300));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Collapse sidebar'));
      await tester.pumpAndSettle();

      expect(find.text('Recents').hitTestable(), findsNothing);
      expect(find.byTooltip('Expand sidebar'), findsOneWidget);
      // The rail repeats New chat, which also lives in the chat header, so use
      // the rail-only labels.
      expect(find.byTooltip('Pinned chats'), findsOneWidget);
      expect(find.byTooltip('Chats'), findsOneWidget);
      expect(find.byTooltip('Library'), findsOneWidget);
    });

    testWidgets('assistant replies have no avatar, bubble or label', (
      tester,
    ) async {
      await pumpApp(tester, size: const Size(375, 812));

      expect(
        find.textContaining('scaled dot-product attention'),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).color ==
                  KrithaColors.assistantBubbleBg,
        ),
        findsNothing,
      );

      // The chat auto-scrolls to the newest message, so the earlier user turn is
      // off-screen and lazily unbuilt. Scroll back up to inspect its bubble.
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('message-seed-2')),
        -300,
        scrollable: find
            .descendant(
              of: find.byType(MessageList),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();

      final bubble = tester.widget<Material>(
        find.byKey(const ValueKey('message-seed-2')),
      );
      expect(bubble.color, KrithaColors.userBubbleBg);
      expect(bubble.borderRadius, BorderRadius.circular(KrithaRadius.xl));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('message-seed-2')),
          matching: find.byType(InkWell),
        ),
        findsOneWidget,
      );
    });

    testWidgets('long-pressing a user message opens the context menu', (
      tester,
    ) async {
      await pumpApp(tester, size: const Size(375, 812));

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('message-seed-2')),
        -300,
        scrollable: find
            .descendant(
              of: find.byType(MessageList),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.byKey(const ValueKey('message-seed-2')));
      await tester.pumpAndSettle();

      final surface = find.byKey(const ValueKey('context-menu-surface'));
      expect(surface, findsOneWidget);
      expect(tester.getSize(surface).width, KrithaDimensions.contextMenuWidth);
      expect(find.textContaining('Oct 21'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Edit message'), findsOneWidget);

      // User-message menus align flush to the bubble's column, not the
      // viewport edge, without adding another gutter.
      expect(
        tester.getTopRight(surface).dx,
        closeTo(
          tester.getTopRight(find.byKey(const ValueKey('message-seed-2'))).dx,
          0.1,
        ),
      );
      final copyText = tester.widget<Text>(find.text('Copy'));
      expect(copyText.style!.fontWeight, FontWeight.w700);
      expect(
        tester
            .widget<HugeIcon>(
              find.descendant(
                of: surface,
                matching: find.byWidgetPredicate(
                  (w) =>
                      w is HugeIcon && w.icon == HugeIcons.strokeRoundedCopy01,
                ),
              ),
            )
            .size,
        KrithaDimensions.contextMenuIconSize,
      );

      // The timestamp header receives the top edge padding; the first action
      // row remains a standard 48px target.
      expect(
        tester
            .getSize(
              find.ancestor(
                of: find.text('Copy'),
                matching: find.byType(InkWell),
              ),
            )
            .height,
        KrithaDimensions.contextMenuItemHeight,
      );

      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.text('Copy'), findsNothing);
    });

    testWidgets('editing a prompt shows the closable restart warning', (
      tester,
    ) async {
      await pumpApp(tester, size: const Size(375, 812));

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('message-seed-2')),
        -300,
        scrollable: find
            .descendant(
              of: find.byType(MessageList),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.longPress(find.byKey(const ValueKey('message-seed-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit message'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('editing-warning')), findsOneWidget);
      expect(
        find.text(
          'Editing this message will restart the conversation from here.',
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Show me a compact Dart example and the softmax formula it uses.',
      );
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );

      // Closing the warning clears the edit state and the draft, like RN.
      await tester.tap(find.byTooltip('Cancel editing'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('editing-warning')), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
    });

    testWidgets('scroll-down button appears away from the bottom and returns', (
      tester,
    ) async {
      await pumpApp(tester, size: const Size(375, 812));
      final button = find.byKey(const ValueKey('scroll-down-button'));
      expect(button.hitTestable(), findsNothing);

      await tester.drag(find.byType(MessageList), const Offset(0, 400));
      await tester.pump();
      expect(button.hitTestable(), findsOneWidget);

      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(button.hitTestable(), findsNothing);
    });

    testWidgets(
      'assistant replies expose copy, read aloud, share and more actions',
      (tester) async {
        await pumpApp(tester, size: const Size(375, 812));

        expect(find.byTooltip('Copy reply'), findsWidgets);
        expect(find.byTooltip('Read aloud'), findsWidgets);
        expect(find.byTooltip('Share reply'), findsWidgets);
        expect(find.byTooltip('More actions'), findsWidgets);
        expect(
          find.byWidgetPredicate(
            (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedShare08,
          ),
          findsWidgets,
        );
        expect(
          find.descendant(
            of: find.byTooltip('More actions').first,
            matching: find.byType(InkWell),
          ),
          findsOneWidget,
        );
        expect(
          tester
              .widget<InkWell>(
                find.descendant(
                  of: find.byTooltip('More actions').first,
                  matching: find.byType(InkWell),
                ),
              )
              .focusColor,
          KrithaColors.contextMenuPressed,
        );
      },
    );

    testWidgets('system back is guarded while the keyboard is open', (
      tester,
    ) async {
      await pumpApp(
        tester,
        size: const Size(375, 812),
        viewInsets: const EdgeInsets.only(bottom: 300),
      );

      expect(
        find.byWidgetPredicate(
          (widget) => widget is PopScope && !widget.canPop,
        ),
        findsWidgets,
      );

      await pumpApp(tester, size: const Size(375, 812));
      expect(
        find.byWidgetPredicate(
          (widget) => widget is PopScope && !widget.canPop,
        ),
        findsNothing,
      );
    });

    testWidgets('sidebar rows are full-height and open their own menu', (
      tester,
    ) async {
      await pumpApp(tester, size: const Size(375, 812));

      await tester.tap(find.byTooltip('Sessions'));
      await tester.pumpAndSettle();

      final recentRow = find.byKey(const ValueKey('session-softmax'));
      expect(
        tester.getSize(recentRow).height,
        KrithaDimensions.sidebarSessionRowHeight,
      );
      expect(
        tester.getSize(recentRow).width,
        greaterThan(KrithaDimensions.contextMenuWidth),
      );

      await tester.longPress(recentRow);
      await tester.pumpAndSettle();

      expect(find.text('Pin'), findsOneWidget);
      expect(find.text('Rename'), findsOneWidget);
      expect(find.text('Archive'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      final surface = find.byKey(const ValueKey('context-menu-surface'));
      expect(tester.getSize(surface).width, KrithaDimensions.contextMenuWidth);
      // Rows own all vertical space: no surface gutter, no separator line.
      // Only the first and last rows add the 8px outer edge inset.
      expect(
        tester.getSize(surface).height,
        4 * KrithaDimensions.contextMenuItemHeight +
            2 * KrithaDimensions.contextMenuEdgeInset,
      );
      final pinRow = find.ancestor(
        of: find.text('Pin'),
        matching: find.byType(InkWell),
      );
      final renameRow = find.ancestor(
        of: find.text('Rename'),
        matching: find.byType(InkWell),
      );
      final deleteRow = find.ancestor(
        of: find.text('Delete'),
        matching: find.byType(InkWell),
      );
      expect(
        tester.getSize(pinRow).height,
        KrithaDimensions.contextMenuItemHeight +
            KrithaDimensions.contextMenuEdgeInset,
      );
      expect(
        tester.getSize(renameRow).height,
        KrithaDimensions.contextMenuItemHeight,
      );
      expect(
        tester.getSize(deleteRow).height,
        KrithaDimensions.contextMenuItemHeight +
            KrithaDimensions.contextMenuEdgeInset,
      );
      expect(tester.getTopLeft(pinRow).dy, tester.getTopLeft(surface).dy);
      expect(
        tester.getBottomRight(deleteRow).dy,
        tester.getBottomRight(surface).dy,
      );
      // The menu is anchored to the press point and may reach the sidebar edge.
      expect(
        tester.getTopRight(surface).dx,
        lessThanOrEqualTo(tester.getTopRight(recentRow).dx + 0.1),
      );

      // Pinning is persisted through SQLite and moves the row into Pinned.
      await tester.tap(find.text('Pin'));
      await tester.pumpAndSettle();
      expect(find.text('Pinned').hitTestable(), findsOneWidget);
      expect(
        tester.getSize(recentRow).height,
        KrithaDimensions.sidebarSessionRowHeight,
      );

      await tester.longPress(recentRow);
      await tester.pumpAndSettle();
      expect(find.text('Unpin'), findsOneWidget);

      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.text('Unpin'), findsNothing);
    });
  });

  group('adaptive composer', () {
    late AppDatabase database;

    setUp(() => database = AppDatabase(NativeDatabase.memory()));
    tearDown(() => database.close());

    Future<void> pumpComposer(
      WidgetTester tester, {
      Size size = const Size(400, 900),
      EdgeInsets viewInsets = EdgeInsets.zero,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      if (viewInsets != EdgeInsets.zero) {
        tester.view.viewInsets = FakeViewPadding(bottom: viewInsets.bottom);
        addTearDown(tester.view.resetViewInsets);
      }
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: size, viewInsets: viewInsets),
          child: ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(database),
              runtimeStatusProvider.overrideWith((ref) async => _runtime),
            ],
            child: const KrithaApp(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    ProviderContainer containerOf(WidgetTester tester) {
      return ProviderScope.containerOf(
        tester.element(find.byType(MessageList)),
      );
    }

    testWidgets('empty compact composer is a capsule with Live Talk action', (
      tester,
    ) async {
      await pumpComposer(tester);

      expect(
        find.byWidgetPredicate(
          (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedAudioLines,
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedArrowUp02,
        ),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('composer-bottom-row')), findsNothing);

      // The mic and the primary blue action keep a deliberate 8px gap.
      final mic = tester.getRect(find.byTooltip('Start dictation'));
      final primary = tester.getRect(find.byTooltip('Live Talk'));
      expect(primary.left - mic.right, KrithaSpacing.s8);
      expect(
        tester.widget<TextField>(find.byType(TextField)).style!.fontSize,
        KrithaText.sizeComposer,
      );
      // Expansion is intentionally immediate: no layout animation.
      expect(
        find.descendant(
          of: find.byType(NormalComposer),
          matching: find.byType(AnimatedSize),
        ),
        findsNothing,
      );
    });

    testWidgets('one line stays compact; wrapped text expands', (tester) async {
      await pumpComposer(tester);

      await tester.enterText(find.byType(TextField), 'Short line');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('composer-bottom-row')), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedArrowUp02,
        ),
        findsOneWidget,
      );

      await tester.enterText(
        find.byType(TextField),
        'This sentence is deliberately long enough to wrap onto a second '
        'line inside the compact composer width so the bottom row appears.',
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('composer-bottom-row')), findsOneWidget);
      expect(find.byKey(const ValueKey('composer-input')), findsOneWidget);
      // The same TextField survives the layout change, so typing can continue.
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('newlines expand the composer and layout stays stable', (
      tester,
    ) async {
      await pumpComposer(tester);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.maxLines, isNull);
      expect(field.textInputAction, TextInputAction.newline);
      expect(find.byKey(const ValueKey('composer-bottom-row')), findsNothing);

      await tester.enterText(find.byType(TextField), 'First line\n');
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('composer-bottom-row')), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'First line\n',
      );

      // With the latched expansion rule the height is identical on every
      // subsequent frame; the previous width-based rule oscillated forever.
      final settled = tester.getSize(find.byType(NormalComposer));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 120));
        expect(tester.getSize(find.byType(NormalComposer)), settled);
      }

      // Removing the trailing newline fits the text on one line again.
      await tester.enterText(find.byType(TextField), 'First line');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('composer-bottom-row')), findsNothing);
    });

    testWidgets('attachments force expansion and can be removed', (
      tester,
    ) async {
      await pumpComposer(tester);
      final container = containerOf(tester);

      container.read(composerProvider.notifier).addAttachments(const [
        ChatAttachment(
          id: 'test-file',
          name: 'softmax.pdf',
          path: '/tmp/softmax.pdf',
          sizeBytes: 2048,
          kind: ChatAttachmentKind.file,
          mimeType: 'application/pdf',
        ),
      ]);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('attachment-preview-test-file')),
        findsOneWidget,
      );
      expect(find.text('softmax.pdf'), findsOneWidget);
      expect(find.byKey(const ValueKey('composer-bottom-row')), findsOneWidget);
      expect(
        tester
            .widget<Material>(
              find.descendant(
                of: find.byTooltip('Remove attachment'),
                matching: find.byType(Material),
              ),
            )
            .color,
        KrithaColors.bgQuaternary,
      );

      await tester.tap(find.byTooltip('Remove attachment'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('attachment-preview-test-file')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('composer-bottom-row')), findsNothing);
    });

    testWidgets('one line with an attachment keeps tight line spacing', (
      tester,
    ) async {
      await pumpComposer(tester);
      final container = containerOf(tester);

      container.read(composerProvider.notifier).addAttachments(const [
        ChatAttachment(
          id: 'spacing-file',
          name: 'softmax.pdf',
          path: '/tmp/softmax.pdf',
          sizeBytes: 2048,
          kind: ChatAttachmentKind.file,
          mimeType: 'application/pdf',
        ),
      ]);
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byType(TextField)).height,
        closeTo(KrithaDimensions.composerLineHeight, 0.1),
      );
      final field = tester.getRect(find.byType(TextField));
      final bottomRow = tester.getRect(
        find.byKey(const ValueKey('composer-bottom-row')),
      );
      expect(bottomRow.top - field.bottom, lessThanOrEqualTo(KrithaSpacing.s6));
    });

    testWidgets('wide windows start with the expanded layout', (tester) async {
      await pumpComposer(tester, size: const Size(1280, 800));

      expect(find.byKey(const ValueKey('composer-bottom-row')), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedAudioLines,
        ),
        findsOneWidget,
      );
    });

    testWidgets('attachment-only messages can be sent and are persisted', (
      tester,
    ) async {
      await pumpComposer(tester);
      final container = containerOf(tester);

      container.read(composerProvider.notifier).addAttachments(const [
        ChatAttachment(
          id: 'test-image',
          name: 'diagram.png',
          path: '/tmp/diagram.png',
          sizeBytes: 4096,
          kind: ChatAttachmentKind.file,
          mimeType: 'image/png',
        ),
      ]);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Send message'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      final stored = await database.allMessages();
      final sent = stored.lastWhere((message) => message.role.name == 'user');
      expect(sent.attachments, hasLength(1));
      expect(sent.attachments.first.name, 'diagram.png');
      expect(find.text('diagram.png'), findsOneWidget);
      expect(find.byKey(const ValueKey('composer-bottom-row')), findsNothing);
    });

    testWidgets('Live Talk replaces the composer and returns to it', (
      tester,
    ) async {
      await pumpComposer(tester);

      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedAudioLines,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(
        find.byWidgetPredicate(
          (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedVideo01,
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedScreenShare,
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedX,
        ),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);

      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedX,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(TextField), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedAudioLines,
        ),
        findsOneWidget,
      );
    });

    testWidgets('attachment picker is the shared context menu', (tester) async {
      await pumpComposer(tester);

      await tester.tap(find.byTooltip('Add attachments'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('context-menu-surface')),
        findsOneWidget,
      );
      final surface = find.byKey(const ValueKey('context-menu-surface'));
      expect(tester.getSize(surface).width, KrithaDimensions.contextMenuWidth);
      // Five rows, no menu-level guttering and no separator lines. The first
      // and last rows own the extra edge insets.
      expect(
        tester.getSize(surface).height,
        5 * KrithaDimensions.contextMenuItemHeight +
            2 * KrithaDimensions.contextMenuEdgeInset,
      );
      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('Photos'), findsOneWidget);
      expect(find.text('Files'), findsOneWidget);
      expect(find.text('Plugins'), findsOneWidget);
      expect(find.text('Think harder'), findsOneWidget);
      expect(find.text('Add to message'), findsNothing);

      // Unimplemented sources are visible but disabled, not fake actions.
      expect(
        find.ancestor(of: find.text('Camera'), matching: find.byType(InkWell)),
        findsNothing,
      );
      expect(
        find.ancestor(of: find.text('Photos'), matching: find.byType(InkWell)),
        findsOneWidget,
      );

      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.text('Photos'), findsNothing);
    });

    testWidgets('attachment menu keeps focus and sits above the keyboard', (
      tester,
    ) async {
      await pumpComposer(
        tester,
        viewInsets: const EdgeInsets.only(bottom: 300),
      );
      await tester.enterText(find.byType(TextField), 'Keep this draft');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );

      await tester.tap(find.byTooltip('Add attachments'));
      await tester.pumpAndSettle();

      final surface = find.byKey(const ValueKey('context-menu-surface'));
      expect(surface, findsOneWidget);
      // Opening the overlay must not steal focus or dismiss the keyboard.
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Keep this draft',
      );

      // The menu is fully above the IME, not hidden behind it.
      final bottom = tester.getBottomRight(surface).dy;
      final keyboardTopLimit =
          900 - 300 - KrithaDimensions.contextMenuScreenMargin;
      expect(bottom, lessThanOrEqualTo(keyboardTopLimit + 0.1));
      expect(bottom, lessThanOrEqualTo(900 - 300));
    });

    testWidgets('no overflow at 320px with expanded content and Live Talk', (
      tester,
    ) async {
      await pumpComposer(tester, size: const Size(320, 640));

      await tester.enterText(
        find.byType(TextField),
        'A very long message that wraps repeatedly so the composer grows and '
        'must stay within the available height without overflowing.',
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Add attachments'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('live talk fits a narrow viewport', (tester) async {
      await pumpComposer(tester, size: const Size(320, 640));

      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedAudioLines,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(tester.takeException(), isNull);
      expect(
        find.byWidgetPredicate(
          (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedVideo01,
        ),
        findsOneWidget,
      );

      // The glowing pill must remain visible and centred even when the four
      // round controls leave very little horizontal room.
      final pill = find.byKey(const ValueKey('live-talk-pill'));
      expect(pill, findsOneWidget);
      expect(tester.getSize(pill).width, greaterThan(40));
      expect(tester.getSize(pill).height, KrithaDimensions.liveTalkPillHeight);
    });

    testWidgets('dictation bar shows the live waveform at 320px', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dictationProvider.overrideWith(_FakeDictationNotifier.new),
          ],
          child: MaterialApp(
            theme: buildKrithaTheme(),
            home: const Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: DictationBar(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(RecordingWaveform), findsOneWidget);
      final waveform = tester.widget<RecordingWaveform>(
        find.byType(RecordingWaveform),
      );
      expect(waveform.barWidth, KrithaDimensions.waveformBarWidth);
      expect(waveform.barGap, KrithaDimensions.waveformBarGap);
      expect(waveform.color, KrithaColors.waveformBar);
      expect(find.byTooltip('Cancel dictation'), findsOneWidget);
      expect(find.byTooltip('Stop and transcribe'), findsOneWidget);
      expect(find.byTooltip('Send dictation'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedSquare,
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedArrowUp02,
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
