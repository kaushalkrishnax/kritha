import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kritha/core/theme.dart';
import 'package:kritha/widgets/create_popup.dart';

void main() {
  Future<void> mountPopupHost(
    WidgetTester tester, {
    required double width,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: OutlinedButton(
                onPressed: () => createPopup<void>(
                  context: context,
                  mobileFullScreen: true,
                  builder: (_) => CreatePopup(
                    title: 'Popup test',
                    actions: [
                      PopupSecondaryButton(
                        label: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                    child: const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('Popup content'),
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('createPopup adapts to a small mobile viewport and dismisses', (
    tester,
  ) async {
    KrithaColors.setLightMode(false);
    await mountPopupHost(tester, width: 360);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Popup test'), findsOneWidget);
    expect(find.text('Popup content'), findsOneWidget);
    expect(
      tester.getRect(find.byType(CreatePopup)).width,
      lessThanOrEqualTo(360),
    );

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Popup test'), findsNothing);
  });

  testWidgets('createPopup uses the light surface on wide layouts', (
    tester,
  ) async {
    KrithaColors.setLightMode(true);
    await mountPopupHost(tester, width: 1024);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Popup test'), findsOneWidget);
    expect(
      tester.getRect(find.byType(CreatePopup)).width,
      lessThanOrEqualTo(560),
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Material && widget.color == KrithaColors.bgSurface,
      ),
      findsWidgets,
    );
    KrithaColors.setLightMode(false);
  });
}
