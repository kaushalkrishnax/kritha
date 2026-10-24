import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/providers.dart';
import 'core/theme.dart';

class KrithaApp extends ConsumerWidget {
  const KrithaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preference = ref.watch(themePreferenceProvider);
    KrithaColors.setLightMode(false);
    final darkTheme = buildKrithaTheme();
    KrithaColors.setLightMode(true);
    final lightTheme = buildKrithaTheme();
    return MaterialApp.router(
      title: 'Kritha',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: preference.themeMode,
      // The palette is static, so animate nothing: a half-finished lerp would
      // mix the old and new token sets until the next frame.
      themeAnimationStyle: AnimationStyle.noAnimation,
      // Put the theme's default text style at the top of the chain so every
      // Text/EditableText descendant inherits DM Sans and the primary text
      // colour, including widgets that provide a TextStyle without either.
      builder: (context, child) {
        watchKrithaPalette(context);
        return DefaultTextStyle.merge(
          style: Theme.of(context).textTheme.bodyMedium!,
          child: child ?? SizedBox.shrink(),
        );
      },
      routerConfig: ref.watch(routerProvider),
    );
  }
}
