import 'dart:async';
import 'dart:ui';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../models/chat_message.dart';
import '../../widgets/context_menu.dart';
import '../../widgets/create_popup.dart';
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

  /// Keeps streamed output in view without fighting a user who scrolled away.
  void _followStreaming() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (position.maxScrollExtent - position.pixels > 120) return;
      position.jumpTo(position.maxScrollExtent);
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
        style: TextStyle(
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
          icon: HugeIcons.strokeRoundedShare08,
          disabled: !hasSession && state.messages.isEmpty,
        ),
        ContextMenuItem(
          id: 'pin',
          label: session?.pinned == true ? 'Unpin' : 'Pin',
          icon: session?.pinned == true
              ? HugeIcons.strokeRoundedPinOff
              : HugeIcons.strokeRoundedPin,
          disabled: !hasSession,
        ),
        ContextMenuItem(
          id: 'files',
          label: 'Uploaded files',
          icon: HugeIcons.strokeRoundedAttachment,
        ),
        ContextMenuItem(
          id: 'find',
          label: 'Find in chat',
          icon: HugeIcons.strokeRoundedSearch01,
          disabled: state.messages.isEmpty,
        ),
        ContextMenuItem(
          id: 'archive',
          label: 'Archive',
          icon: HugeIcons.strokeRoundedArchive,
          disabled: !hasSession,
        ),
        ContextMenuItem(
          id: 'delete',
          label: 'Delete',
          icon: HugeIcons.strokeRoundedDelete02,
          destructive: true,
          disabled: !hasSession,
          focusColor: Color(0x33FF453A),
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
    await createPopup<void>(
      context: context,
      builder: (_) => CreatePopup(
        title: 'Uploaded files',
        actions: [
          PopupSecondaryButton(
            label: 'Close',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
        child: SizedBox(
          child: files.isEmpty
              ? Text(
                  'No uploaded files in this chat.',
                  style: TextStyle(color: KrithaColors.textMuted),
                )
              : ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: 360),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: files.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: KrithaColors.borderFaint),
                    itemBuilder: (context, index) {
                      final file = files[index];
                      return Material(
                        color: Colors.transparent,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: KrithaIcon(
                            icon: file.isImage
                                ? HugeIcons.strokeRoundedAlbum01
                                : HugeIcons.strokeRoundedAttachment,
                            size: KrithaIcons.md,
                            color: KrithaColors.iconMuted,
                          ),
                          title: Text(
                            file.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(file.readableSize),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _showFindInChat(ChatState state) async {
    final queryController = TextEditingController();
    await createPopup<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final query = queryController.text.trim().toLowerCase();
          final matches = query.isEmpty
              ? <ChatMessage>[]
              : state.messages
                    .where(
                      (message) => message.text.toLowerCase().contains(query),
                    )
                    .toList();
          return CreatePopup(
            title: 'Find in chat',
            actions: [
              PopupSecondaryButton(
                label: 'Close',
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
            ],
            child: SizedBox(
              height: 360,
              child: Padding(
                padding: EdgeInsets.all(KrithaSpacing.s16),
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
                    SizedBox(height: KrithaSpacing.s12),
                    Expanded(
                      child: matches.isEmpty
                          ? Center(
                              child: Text(
                                query.isEmpty
                                    ? 'Type to search this chat.'
                                    : 'No matches.',
                                style: TextStyle(color: KrithaColors.textMuted),
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
            ),
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
    watchKrithaPalette(context);
    ref.listen(chatControllerProvider, (previous, next) {
      final previousState = previous?.value;
      final nextState = next.value;
      final previousCount = previousState?.messages.length ?? 0;
      final nextCount = nextState?.messages.length ?? 0;
      final sessionChanged =
          previousState?.currentSessionId != nextState?.currentSessionId;
      final streamingChanged =
          previousState?.streamingText != nextState?.streamingText;
      final failureAppeared =
          previousState?.failure == null && nextState?.failure != null;
      if (sessionChanged) {
        ref.read(composerProvider.notifier).cancelEditing();
        _scaffoldKey.currentState?.closeDrawer();
        _scrollToBottom();
      } else if (previousCount != nextCount || failureAppeared) {
        _scrollToBottom();
      } else if (streamingChanged && nextState?.sending == true) {
        _followStreaming();
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
            onCollapse: isDocked ? () => _toggleSidebar(viewport) : null,
          );

          final chatArea = _ChatArea(
            viewport: viewport,
            chat: chat,
            scrollController: _scrollController,
            onMenu: () => _toggleSidebar(viewport),
            onNewChat: _newChat,
            onChatMenu: _openChatMenu,
            onRetry: () => ref.invalidate(chatControllerProvider),
            onReplyRetry: () =>
                ref.read(chatControllerProvider.notifier).retryReply(),
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
                shape: RoundedRectangleBorder(),
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
                  AnimatedContainer(
                    duration: KrithaMotion.normal,
                    curve: Curves.easeOutCubic,
                    width: _dockedSidebarOpen
                        ? KrithaDimensions.sidebarWidth
                        : 56,
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.centerLeft,
                        minWidth: KrithaDimensions.sidebarWidth,
                        maxWidth: KrithaDimensions.sidebarWidth,
                        child: AnimatedSwitcher(
                          duration: KrithaMotion.fast,
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          child: _dockedSidebarOpen
                              ? KeyedSubtree(
                                  key: const ValueKey('docked-sidebar'),
                                  // Stack children get loose constraints; keep
                                  // the panel at its docked width.
                                  child: SizedBox(
                                    width: KrithaDimensions.sidebarWidth,
                                    child: sidebar,
                                  ),
                                )
                              : Align(
                                  key: const ValueKey('docked-rail'),
                                  alignment: Alignment.centerLeft,
                                  child: CompactSidebarRail(
                                    onExpand: () => _toggleSidebar(viewport),
                                    onNewChat: _newChat,
                                    onSettings: _openSettings,
                                  ),
                                ),
                        ),
                      ),
                    ),
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
    required this.onReplyRetry,
    this.sidebarOpen,
  });

  final KrithaViewport viewport;
  final AsyncValue<ChatState> chat;
  final ScrollController scrollController;
  final VoidCallback onMenu;
  final VoidCallback onNewChat;
  final void Function(BuildContext buttonContext) onChatMenu;
  final VoidCallback onRetry;
  final VoidCallback onReplyRetry;
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
        key: const ValueKey('chat-background'),
        color: KrithaColors.bgDeepest,
        child: Stack(
          children: [
            Positioned.fill(
              child: chat.when(
                data: (state) => state.messages.isEmpty && !state.sending
                    ? _EmptyChat()
                    : MessageList(
                        messages: state.messages,
                        sending: state.sending,
                        streamingText: state.streamingText,
                        failure: state.failure,
                        onRetry: widget.onReplyRetry,
                        scrollController: widget.scrollController,
                        topPadding: KrithaDimensions.headerContentTopPadding,
                        bottomPadding: _composerHeight + KrithaSpacing.s12,
                      ),
                loading: () => _LoadingMessages(),
                error: (error, stackTrace) =>
                    _ChatError(error: error, onRetry: widget.onRetry),
              ),
            ),
            Positioned(
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
                showMenuButton: !viewport.usesDockedSidebar,
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
                  child: _ComposerBackdrop(),
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

class _HeaderBackdrop extends StatelessWidget {
  const _HeaderBackdrop();

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
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

class _ComposerBackdrop extends StatelessWidget {
  const _ComposerBackdrop();

  @override
  Widget build(BuildContext context) {
    final scrim = KrithaColors.composerBackdrop;
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x00000000), Color(0xFF000000)],
        stops: [0.0, 0.55],
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
                scrim.withValues(alpha: 0),
                scrim.withValues(
                  alpha: KrithaDimensions.composerBackdropScrimOpacity * 0.55,
                ),
                scrim.withValues(
                  alpha: KrithaDimensions.composerBackdropScrimOpacity,
                ),
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

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
            key: ValueKey('scroll-down-button'),
            color: KrithaColors.scrollDownSurface,
            shape: CircleBorder(
              side: BorderSide(color: KrithaColors.borderSubtle),
            ),
            elevation: 4,
            shadowColor: KrithaColors.composerShadow,
            child: InkWell(
              customBorder: CircleBorder(),
              onTap: _jumpToBottom,
              mouseCursor: SystemMouseCursors.click,
              child: SizedBox(
                width: KrithaDimensions.scrollDownButtonSize,
                height: KrithaDimensions.scrollDownButtonSize,
                child: KrithaIcon(
                  icon: HugeIcons.strokeRoundedArrowDown02,
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
        padding: EdgeInsets.all(KrithaSpacing.s24),
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
              child: KrithaIcon(
                icon: HugeIcons.strokeRoundedSparkles,
                size: KrithaIcons.lg,
                color: KrithaColors.accentLightBlue,
              ),
            ),
            SizedBox(height: KrithaSpacing.s16),
            Text(
              'Start a new chat',
              style: TextStyle(
                fontSize: KrithaText.sizeLg,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: KrithaSpacing.s6),
            Text(
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
    return Center(
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
        padding: EdgeInsets.all(KrithaSpacing.s24),
        child: Container(
          padding: EdgeInsets.all(KrithaSpacing.s18),
          decoration: BoxDecoration(
            color: KrithaColors.bgSurface,
            borderRadius: BorderRadius.circular(KrithaRadius.md),
            border: Border.all(color: KrithaColors.borderSubtle),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              KrithaIcon(
                icon: HugeIcons.strokeRoundedDatabase,
                color: KrithaColors.error,
                size: KrithaIcons.lg,
              ),
              SizedBox(height: KrithaSpacing.s10),
              Text(
                'Local history could not open',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: KrithaSpacing.s4),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: KrithaText.sizeXs,
                  color: KrithaColors.textMuted,
                ),
              ),
              SizedBox(height: KrithaSpacing.s12),
              FilledButton.tonal(onPressed: onRetry, child: Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}
