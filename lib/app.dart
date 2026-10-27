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
      themeAnimationStyle: AnimationStyle.noAnimation,
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
