import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/responsive.dart';
import '../../../../core/theme.dart';
import '../../dictation_controller.dart';
import 'composer_controller.dart';
import 'dictation_bar.dart';
import 'live_talk_bar.dart';
import 'normal_composer.dart';

/// Chooses between the normal composer and the Live Talk capsule and keeps the
/// readable column centred on wide windows.
class ChatComposer extends ConsumerWidget {
  const ChatComposer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(composerProvider);
    final dictation = ref.watch(dictationProvider);
    final viewport = viewportOf(MediaQuery.sizeOf(context).width);

    final Widget content = dictation.isActive
        ? DictationBar(key: ValueKey('dictation-bar'))
        : state.isLiveTalkActive
        ? LiveTalkBar(
            key: const ValueKey('live-talk'),
            phase: state.liveTalkPhase,
            onTogglePause: () =>
                ref.read(composerProvider.notifier).toggleLiveTalkPause(),
            onStop: () =>
                ref.read(composerProvider.notifier).setLiveTalkActive(false),
          )
        : NormalComposer(
            key: const ValueKey('normal-composer'),
            viewport: viewport,
          );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: KrithaDimensions.maxContentWidth,
        ),
        child: AnimatedSwitcher(
          duration: KrithaMotion.normal,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SizeTransition(
                sizeFactor: animation,
                alignment: Alignment.bottomCenter,
                child: child,
              ),
            );
          },
          child: content,
        ),
      ),
    );
  }
}
