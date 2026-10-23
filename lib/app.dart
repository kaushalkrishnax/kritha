import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/theme.dart';

class KrithaApp extends ConsumerWidget {
  const KrithaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Kritha',
      debugShowCheckedModeBanner: false,
      theme: buildKrithaTheme(),
      // Put the theme's default text style at the top of the chain so every
      // Text/EditableText descendant inherits DM Sans and the primary text
      // colour, including widgets that provide a TextStyle without either.
      builder: (context, child) => DefaultTextStyle.merge(
        style: Theme.of(context).textTheme.bodyMedium!,
        child: child ?? const SizedBox.shrink(),
      ),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
