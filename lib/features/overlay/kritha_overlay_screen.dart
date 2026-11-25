import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme.dart';
import '../../models/chat_message.dart';
import '../../services/wake_word_bridge.dart';
import '../../widgets/glass_surface.dart';
import '../chat/chat_controller.dart';
import '../chat/speech_playback_controller.dart';
import '../chat/widgets/composer/chat_composer.dart';
import '../chat/widgets/markdown_view.dart';
import '../chat/widgets/response_actions.dart';

/// Translucent overlay surface shown when wake word activates outside the app.
class KrithaOverlayScreen extends ConsumerWidget {
  const KrithaOverlayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatControllerProvider).value;
    final messages = chat?.messages ?? const <ChatMessage>[];
    final latestUser = messages.where((m) => m.role == ChatRole.user).lastOrNull;
    final latestAssistant =
        messages.where((m) => m.role == ChatRole.assistant).lastOrNull;
    final streaming = chat?.streamingText;
    final sending = chat?.sending ?? false;
    final failure = chat?.failure;

    final replyText = (streaming != null && streaming.isNotEmpty)
        ? streaming
        : (latestAssistant?.text ?? '');

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => WakeWordBridge.dismissOverlay(),
              child: Container(color: Colors.black.withValues(alpha: 0.48)),
            ),
          ),
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (latestUser != null && latestUser.text.trim().isNotEmpty)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      KrithaSpacing.s16,
                      0,
                      KrithaSpacing.s16,
                      KrithaSpacing.s8,
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 300),
                        padding: EdgeInsets.symmetric(
                          horizontal: KrithaSpacing.s14,
                          vertical: KrithaSpacing.s10,
                        ),
                        decoration: BoxDecoration(
                          color: KrithaColors.accentBlue,
                          borderRadius: BorderRadius.circular(KrithaRadius.xl),
                        ),
                        child: Text(
                          latestUser.text,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: KrithaColors.textOnAccent,
                            fontSize: KrithaText.sizeSm,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (replyText.isNotEmpty || sending || failure != null)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      KrithaSpacing.s16,
                      0,
                      KrithaSpacing.s16,
                      KrithaSpacing.s10,
                    ),
                    child: KrithaGlassSurface(
                      borderRadius: KrithaRadius.xl,
                      padding: EdgeInsets.all(KrithaSpacing.s14),
                      border: Border.all(color: KrithaColors.borderSubtle),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Kritha',
                                    style: TextStyle(
                                      fontSize: KrithaText.sizeXs,
                                      fontWeight: FontWeight.w700,
                                      color: KrithaColors.accentLightBlue,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    tooltip: 'Open in app',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () =>
                                        WakeWordBridge.openMainApp(),
                                    icon: KrithaIcon(
                                      icon: HugeIcons.strokeRoundedArrowExpand,
                                      size: KrithaIcons.sm,
                                      color: KrithaColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                              if (failure != null && !sending)
                                Text(
                                  failure.message,
                                  style: TextStyle(
                                    color: KrithaColors.error,
                                    fontSize: KrithaText.sizeSm,
                                  ),
                                )
                              else if (replyText.isEmpty && sending)
                                Text(
                                  'Thinking…',
                                  style: TextStyle(
                                    color: KrithaColors.accentLightBlue,
                                    fontStyle: FontStyle.italic,
                                  ),
                                )
                              else
                                MarkdownView(data: replyText),
                              if (replyText.isNotEmpty &&
                                  !sending &&
                                  latestAssistant != null)
                                ResponseActions(
                                  text: replyText,
                                  isSpeaking: ref.watch(
                                    speechPlaybackProvider.select(
                                      (s) => s.isPlaying(latestAssistant.id),
                                    ),
                                  ),
                                  onSpeak: () => ref
                                      .read(speechPlaybackProvider.notifier)
                                      .toggleSpeak(
                                        messageId: latestAssistant.id,
                                        text: replyText,
                                      ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                const ChatComposer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
