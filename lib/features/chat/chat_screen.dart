import 'dart:async';
import 'dart:ui';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../models/chat_message.dart';
import '../../widgets/context_menu.dart';
import 'chat_controller.dart';
import 'widgets/chat_header.dart';
import 'widgets/chat_sidebar.dart';
import 'widgets/composer/chat_composer.dart';
import 'widgets/composer/composer_controller.dart';
import 'widgets/message_list.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _scrollController = ScrollController();
  bool _dockedSidebarOpen = true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: KrithaMotion.slow,
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _newChat() {
    _scaffoldKey.currentState?.closeDrawer();
    ref.read(chatControllerProvider.notifier).newChat();
    ref.read(composerProvider.notifier).clearDraft();
  }

  Future<void> _openSettings() async {
    _scaffoldKey.currentState?.closeDrawer();
    await context.push('/settings');
    if (mounted) {
      // History may have been reset from settings.
      _scrollToBottom();
    }
  }

  Future<void> _openChatMenu(BuildContext anchorContext) async {
    final state = ref.read(chatControllerProvider).value;
    if (state == null) return;
    final session = state.currentSession;
    final title = session?.title ?? 'New chat';
    final hasSession = session != null;
    final anchor = ContextMenuAnchor.fromContext(anchorContext);
    final anchorBox = anchorContext.findRenderObject() as RenderBox?;
    final origin = anchorBox == null
        ? null
        : anchorBox.localToGlobal(Offset.zero) & anchorBox.size;

    final selected = await showKrithaContextMenu(
      context: anchorContext,
      anchor: anchor,
      align: ContextMenuAlign.right,
      header: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: KrithaColors.textMuted,
          fontSize: KrithaText.sizeMd,
          fontWeight: FontWeight.w500,
          height: 1.2,
        ),
      ),
      items: [
        ContextMenuItem(
          id: 'share',
          label: 'Share',
          icon: LucideIcons.share2,
          disabled: !hasSession && state.messages.isEmpty,
        ),
        ContextMenuItem(
          id: 'pin',
          label: session?.pinned == true ? 'Unpin' : 'Pin',
          icon: session?.pinned == true ? LucideIcons.pinOff : LucideIcons.pin,
          disabled: !hasSession,
        ),
        const ContextMenuItem(
          id: 'files',
          label: 'Uploaded files',
          icon: LucideIcons.paperclip,
        ),
        ContextMenuItem(
          id: 'find',
          label: 'Find in chat',
          icon: LucideIcons.search,
          disabled: state.messages.isEmpty,
        ),
        ContextMenuItem(
          id: 'archive',
          label: 'Archive',
          icon: LucideIcons.archive,
          disabled: !hasSession,
        ),
        ContextMenuItem(
          id: 'delete',
          label: 'Delete',
          icon: LucideIcons.trash2,
          destructive: true,
          disabled: !hasSession,
        ),
      ],
    );
    if (!mounted || selected == null) return;

    switch (selected) {
      case 'share':
        await _shareChat(state, origin);
      case 'pin':
        if (session != null) {
          await ref
              .read(chatControllerProvider.notifier)
              .togglePinned(session.id);
        }
      case 'files':
        await _showUploadedFiles(state);
      case 'find':
        await _showFindInChat(state);
      case 'archive':
        if (session != null) {
          await ref
              .read(chatControllerProvider.notifier)
              .archiveSession(session.id);
        }
      case 'delete':
        if (session != null) {
          await ref
              .read(chatControllerProvider.notifier)
              .deleteSession(session.id);
        }
    }
  }

  Future<void> _shareChat(ChatState state, Rect? origin) async {
    final buffer = StringBuffer(state.currentSession?.title ?? 'Kritha chat');
    for (final message in state.messages) {
      buffer
        ..writeln()
        ..writeln()
        ..write(message.role == ChatRole.user ? 'You: ' : 'Kritha: ')
        ..write(message.text);
    }
    try {
      await SharePlus.instance.share(
        ShareParams(text: buffer.toString(), sharePositionOrigin: origin),
      );
    } on Object {
      if (mounted) _snack("Couldn't open the share sheet.");
    }
  }

  Future<void> _showUploadedFiles(ChatState state) async {
    final files = state.messages
        .expand((message) => message.attachments)
        .toList();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: KrithaColors.bgSurface,
        title: const Text('Uploaded files'),
        content: SizedBox(
          width: 360,
          child: files.isEmpty
              ? const Text(
                  'No uploaded files in this chat.',
                  style: TextStyle(color: KrithaColors.textMuted),
                )
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: files.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: KrithaColors.borderFaint),
                    itemBuilder: (context, index) {
                      final file = files[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          file.isImage
                              ? LucideIcons.image
                              : LucideIcons.fileText,
                          color: KrithaColors.iconMuted,
                        ),
                        title: Text(
                          file.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(file.readableSize),
                      );
                    },
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showFindInChat(ChatState state) async {
    final queryController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final query = queryController.text.trim().toLowerCase();
          final matches = query.isEmpty
              ? const <ChatMessage>[]
              : state.messages
                    .where(
                      (message) => message.text.toLowerCase().contains(query),
                    )
                    .toList();
          return AlertDialog(
            backgroundColor: KrithaColors.bgSurface,
            title: const Text('Find in chat'),
            content: SizedBox(
              width: 380,
              height: 360,
              child: Column(
                children: [
                  TextField(
                    controller: queryController,
                    autofocus: true,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Search messages',
                    ),
                  ),
                  const SizedBox(height: KrithaSpacing.s12),
                  Expanded(
                    child: matches.isEmpty
                        ? Center(
                            child: Text(
                              query.isEmpty
                                  ? 'Type to search this chat.'
                                  : 'No matches.',
                              style: const TextStyle(
                                color: KrithaColors.textMuted,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: matches.length,
                            separatorBuilder: (_, _) => Divider(
                              height: 1,
                              color: KrithaColors.borderFaint,
                            ),
                            itemBuilder: (context, index) {
                              final message = matches[index];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  message.text,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  message.role == ChatRole.user
                                      ? 'You'
                                      : 'Kritha',
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
    queryController.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _toggleSidebar(KrithaViewport viewport) {
    if (viewport.usesDockedSidebar) {
      setState(() => _dockedSidebarOpen = !_dockedSidebarOpen);
    } else {
      _scaffoldKey.currentState?.openDrawer();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(chatControllerProvider, (previous, next) {
      final previousCount = previous?.value?.messages.length ?? 0;
      final nextCount = next.value?.messages.length ?? 0;
      final sessionChanged =
          previous?.value?.currentSessionId != next.value?.currentSessionId;
      if (sessionChanged) {
        ref.read(composerProvider.notifier).cancelEditing();
        _scaffoldKey.currentState?.closeDrawer();
        _scrollToBottom();
      } else if (previousCount != nextCount) {
        _scrollToBottom();
      }
    });

    final chat = ref.watch(chatControllerProvider);

    return _KeyboardBackGuard(
      child: ResponsiveBuilder(
        builder: (context, viewport) {
          final isDocked = viewport.usesDockedSidebar;
          final sidebar = ChatSidebar(
            onNewChat: _newChat,
            onSettings: _openSettings,
          );

          final chatArea = _ChatArea(
            viewport: viewport,
            chat: chat,
            scrollController: _scrollController,
            onMenu: () => _toggleSidebar(viewport),
            onNewChat: _newChat,
            onChatMenu: _openChatMenu,
            onRetry: () => ref.invalidate(chatControllerProvider),
            sidebarOpen: isDocked ? _dockedSidebarOpen : null,
          );

          if (!isDocked) {
            return Scaffold(
              key: _scaffoldKey,
              backgroundColor: KrithaColors.bgDeepest,
              drawerScrimColor: KrithaColors.bgScrim,
              drawerEdgeDragWidth: 32,
              drawer: Drawer(
                width: ChatSidebar.drawerWidthFor(
                  MediaQuery.sizeOf(context).width,
                ),
                backgroundColor: KrithaColors.bgDeepest,
                surfaceTintColor: Colors.transparent,
                shape: const RoundedRectangleBorder(),
                elevation: 12,
                child: sidebar,
              ),
              body: chatArea,
            );
          }

          return Scaffold(
            key: _scaffoldKey,
            backgroundColor: KrithaColors.bgDeepest,
            body: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  if (_dockedSidebarOpen)
                    SizedBox(
                      width: KrithaDimensions.sidebarWidth,
                      child: sidebar,
                    ),
                  Expanded(child: chatArea),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _KeyboardBackGuard extends StatelessWidget {
  const _KeyboardBackGuard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return PopScope(
      canPop: !keyboardVisible,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Android's back button should dismiss the IME before it can close the
        // app. Some keyboards/embeddings do not consume it themselves, so do it
        // explicitly whenever the system asks us to pop with the IME open.
        FocusManager.instance.primaryFocus?.unfocus();
        SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      },
      child: child,
    );
  }
}

class _ChatArea extends StatefulWidget {
  const _ChatArea({
    required this.viewport,
    required this.chat,
    required this.scrollController,
    required this.onMenu,
    required this.onNewChat,
    required this.onChatMenu,
    required this.onRetry,
    this.sidebarOpen,
  });

  final KrithaViewport viewport;
  final AsyncValue<ChatState> chat;
  final ScrollController scrollController;
  final VoidCallback onMenu;
  final VoidCallback onNewChat;
  final void Function(BuildContext buttonContext) onChatMenu;
  final VoidCallback onRetry;
  final bool? sidebarOpen;

  @override
  State<_ChatArea> createState() => _ChatAreaState();
}

class _ChatAreaState extends State<_ChatArea> {
  final _composerKey = GlobalKey();
  double _composerHeight = 120;
  bool _didInitialScroll = false;

  void _measureComposer() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _composerKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      if ((box.size.height - _composerHeight).abs() <= 0.5) return;
      setState(() => _composerHeight = box.size.height);
    });
  }

  /// The transcript is opened at the latest turn. Wait two frames so the
  /// measured composer padding and the first message layout are both applied
  /// before jumping; otherwise the scroll extent can grow after the jump and
  /// leave the "scroll to bottom" affordance visible on a fresh chat.
  void _scheduleInitialScroll() {
    if (_didInitialScroll) return;
    final messages = widget.chat.asData?.value.messages;
    if (messages == null || messages.isEmpty) return;
    _didInitialScroll = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final controller = widget.scrollController;
        if (!controller.hasClients) return;
        controller.jumpTo(controller.position.maxScrollExtent);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    _measureComposer();
    _scheduleInitialScroll();
    final viewport = widget.viewport;
    final chat = widget.chat;

    return SafeArea(
      bottom: false,
      left: viewport.usesDockedSidebar,
      child: ColoredBox(
        color: KrithaColors.bgDeepest,
        child: Stack(
          children: [
            Positioned.fill(
              child: chat.when(
                data: (state) => state.messages.isEmpty && !state.sending
                    ? const _EmptyChat()
                    : MessageList(
                        messages: state.messages,
                        sending: state.sending,
                        scrollController: widget.scrollController,
                        topPadding: KrithaDimensions.headerContentTopPadding,
                        bottomPadding: _composerHeight + KrithaSpacing.s12,
                      ),
                loading: () => const _LoadingMessages(),
                error: (error, stackTrace) =>
                    _ChatError(error: error, onRetry: widget.onRetry),
              ),
            ),
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: KrithaDimensions.headerFadeHeight,
              child: IgnorePointer(child: _HeaderBackdrop()),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ChatHeader(
                onMenu: widget.onMenu,
                onNewChat: widget.onNewChat,
                onChatMenu: widget.onChatMenu,
                menuTooltip: viewport.usesDockedSidebar
                    ? ((widget.sidebarOpen ?? true)
                          ? 'Hide sidebar'
                          : 'Show sidebar')
                    : 'Sessions',
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: SizedBox(
                  height:
                      _composerHeight + KrithaDimensions.composerBackdropLift,
                  child: const _ComposerBackdrop(),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: _composerHeight + KrithaDimensions.scrollDownButtonLift,
              child: Center(
                child: _ScrollDownButton(controller: widget.scrollController),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ChatComposer(key: _composerKey),
            ),
          ],
        ),
      ),
    );
  }
}

/// Blurred, darkened top band behind the transparent header, matching the RN
/// chat's top fade while keeping the pills and transcript legible.
class _HeaderBackdrop extends StatelessWidget {
  const _HeaderBackdrop();

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF000000), Color(0x00000000)],
      ).createShader(bounds),
      blendMode: BlendMode.dstIn,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: KrithaDimensions.headerBackdropBlurSigma,
          sigmaY: KrithaDimensions.headerBackdropBlurSigma,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                KrithaColors.bgDeepest.withValues(alpha: 0.92),
                KrithaColors.bgDeepest.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Soft blurred/dimmed band behind the floating composer. The top edge fades
/// out so the transcript appears to dissolve under the composer rather than
/// stopping at a hard line.
class _ComposerBackdrop extends StatelessWidget {
  const _ComposerBackdrop();

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x00000000), Color(0xFF000000)],
        stops: [0.0, 0.45],
      ).createShader(bounds),
      blendMode: BlendMode.dstIn,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: KrithaDimensions.composerBackdropBlurSigma,
          sigmaY: KrithaDimensions.composerBackdropBlurSigma,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0x00000000),
                KrithaColors.bgDeepest.withValues(
                  alpha: KrithaDimensions.composerBackdropScrimOpacity,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Scroll-to-bottom affordance ported from `ChatMessages.tsx`.
///
/// It appears whenever the transcript is more than 80px from the bottom,
/// auto-hides after 1.5s of inactivity, fades over 180ms and jumps to the end
/// when pressed.
class _ScrollDownButton extends StatefulWidget {
  const _ScrollDownButton({required this.controller});

  final ScrollController controller;

  @override
  State<_ScrollDownButton> createState() => _ScrollDownButtonState();
}

class _ScrollDownButtonState extends State<_ScrollDownButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: KrithaMotion.composer,
  );
  Timer? _hideTimer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleScroll());
  }

  @override
  void didUpdateWidget(_ScrollDownButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_handleScroll);
    widget.controller.addListener(_handleScroll);
    _handleScroll();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    widget.controller.removeListener(_handleScroll);
    _fade.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!mounted || !widget.controller.hasClients) return;
    final position = widget.controller.position;
    final distance = position.maxScrollExtent - position.pixels;
    final nearBottom = distance <= 80 || position.maxScrollExtent <= 0;
    if (nearBottom) {
      _hide();
    } else {
      _show();
    }
  }

  void _show() {
    _hideTimer?.cancel();
    if (!_visible) setState(() => _visible = true);
    _fade.forward();
    _hideTimer = Timer(KrithaDimensions.scrollDownAutoHide, _hide);
  }

  void _hide() {
    _hideTimer?.cancel();
    _hideTimer = null;
    if (!_visible) return;
    _fade.reverse().then((_) {
      if (mounted) setState(() => _visible = false);
    });
  }

  void _jumpToBottom() {
    _hide();
    if (!widget.controller.hasClients) return;
    widget.controller.animateTo(
      widget.controller.position.maxScrollExtent,
      duration: KrithaMotion.slow,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !_visible,
      child: FadeTransition(
        opacity: _fade,
        child: Tooltip(
          message: 'Scroll to bottom',
          child: Material(
            key: const ValueKey('scroll-down-button'),
            color: KrithaColors.bgTertiary,
            shape: const CircleBorder(),
            elevation: 6,
            shadowColor: KrithaColors.bgDeepest,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _jumpToBottom,
              child: SizedBox(
                width: KrithaDimensions.scrollDownButtonSize,
                height: KrithaDimensions.scrollDownButtonSize,
                child: const Icon(
                  LucideIcons.arrowDown,
                  size: KrithaIcons.lg,
                  color: KrithaColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KrithaSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: KrithaColors.bgSecondary,
                borderRadius: BorderRadius.circular(KrithaRadius.md),
                border: Border.all(color: KrithaColors.borderSubtle),
              ),
              child: const Icon(
                LucideIcons.sparkles,
                size: KrithaIcons.lg,
                color: KrithaColors.accentLightBlue,
              ),
            ),
            const SizedBox(height: KrithaSpacing.s16),
            const Text(
              'Start a new chat',
              style: TextStyle(
                fontSize: KrithaText.sizeLg,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: KrithaSpacing.s6),
            const Text(
              'Ask anything. Your conversations stay on this device.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: KrithaColors.textMuted,
                fontSize: KrithaText.sizeSm,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingMessages extends StatelessWidget {
  const _LoadingMessages();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 1.8,
              color: KrithaColors.accentLightBlue,
            ),
          ),
          SizedBox(height: KrithaSpacing.s14),
          Text(
            'Opening local history…',
            style: TextStyle(
              fontSize: KrithaText.sizeSm,
              color: KrithaColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatError extends StatelessWidget {
  const _ChatError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KrithaSpacing.s24),
        child: Container(
          padding: const EdgeInsets.all(KrithaSpacing.s18),
          decoration: BoxDecoration(
            color: KrithaColors.bgSurface,
            borderRadius: BorderRadius.circular(KrithaRadius.md),
            border: Border.all(color: KrithaColors.borderSubtle),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                LucideIcons.database,
                color: KrithaColors.error,
                size: KrithaIcons.lg,
              ),
              const SizedBox(height: KrithaSpacing.s10),
              const Text(
                'Local history could not open',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: KrithaSpacing.s4),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: KrithaText.sizeXs,
                  color: KrithaColors.textMuted,
                ),
              ),
              const SizedBox(height: KrithaSpacing.s12),
              FilledButton.tonal(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
