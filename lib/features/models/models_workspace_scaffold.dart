import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../widgets/back_navigation.dart';
import '../../widgets/context_menu.dart';
import '../chat/chat_controller.dart';
import '../chat/widgets/chat_sidebar.dart';
import '../chat/widgets/composer/composer_controller.dart';
import 'widgets/workspace_header.dart';

const exploreModelsLocation = '/models/explore';

enum ModelsWorkspaceDestination {
  active('/models/active', 'Active Models'),
  providers('/models/providers', 'Provider Models');

  const ModelsWorkspaceDestination(this.location, this.title);

  final String location;
  final String title;
}

class ModelsWorkspaceScaffold extends ConsumerStatefulWidget {
  const ModelsWorkspaceScaffold({
    super.key,
    required this.destination,
    required this.child,
    this.maxContentWidth = 900,
  });

  final ModelsWorkspaceDestination destination;
  final Widget child;
  final double maxContentWidth;

  @override
  ConsumerState<ModelsWorkspaceScaffold> createState() =>
      _ModelsWorkspaceScaffoldState();
}

class _ModelsWorkspaceScaffoldState
    extends ConsumerState<ModelsWorkspaceScaffold> {
  bool _sidebarOpen = true;

  void _newChat() {
    ref.read(chatControllerProvider.notifier).newChat();
    ref.read(composerProvider.notifier).clearDraft();
    context.go('/chat');
  }

  void _openSettings() => context.push('/settings');

  void _openChat() => context.go('/chat');

  Future<void> _showDestinationMenu(BuildContext anchorContext) async {
    final selected = await showKrithaContextMenu(
      context: anchorContext,
      anchor: ContextMenuAnchor.fromContext(anchorContext),
      items: [
        for (final destination in ModelsWorkspaceDestination.values)
          ContextMenuItem(
            id: destination.location,
            label: destination.title,
            icon: destination == widget.destination
                ? HugeIcons.strokeRoundedCheckmarkCircle02
                : null,
          ),
      ],
    );
    if (!mounted ||
        selected == null ||
        selected == widget.destination.location) {
      return;
    }
    context.push(selected);
  }

  Widget _content(KrithaViewport viewport) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.maxContentWidth),
        child: Column(
          children: [
            WorkspaceHeader(
              title: widget.destination.title,
              onBack: () => goBackOrExit(context),
              showBack: !viewport.isWide,
              titleTooltip: 'Switch models workspace',
              onTitleTap: viewport.isWide ? null : _showDestinationMenu,
              actions: [
                WorkspaceOutlinedAction(
                  label: 'Explore Models',
                  icon: HugeIcons.strokeRoundedSearch01,
                  onPressed: () => context.push(exploreModelsLocation),
                ),
              ],
            ),
            Expanded(child: widget.child),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    watchKrithaPalette(context);
    return ResponsiveBuilder(
      builder: (context, viewport) {
        if (!viewport.usesDockedSidebar) {
          return Scaffold(
            backgroundColor: KrithaColors.bgBase,
            body: SafeArea(child: _content(viewport)),
          );
        }

        final sidebar = ChatSidebar(
          onNewChat: _newChat,
          onSettings: _openSettings,
          onCollapse: () => setState(() => _sidebarOpen = !_sidebarOpen),
          onSessionOpen: _openChat,
          selectedWorkspacePath: widget.destination.location,
        );

        return Scaffold(
          backgroundColor: KrithaColors.bgDeepest,
          body: SafeArea(
            bottom: false,
            child: Row(
              children: [
                AnimatedContainer(
                  duration: KrithaMotion.normal,
                  curve: Curves.easeOutCubic,
                  width: _sidebarOpen ? KrithaDimensions.sidebarWidth : 56,
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.centerLeft,
                      minWidth: KrithaDimensions.sidebarWidth,
                      maxWidth: KrithaDimensions.sidebarWidth,
                      child: AnimatedSwitcher(
                        duration: KrithaMotion.fast,
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: _sidebarOpen
                            ? KeyedSubtree(
                                key: const ValueKey('docked-sidebar'),
                                child: SizedBox(
                                  width: KrithaDimensions.sidebarWidth,
                                  child: sidebar,
                                ),
                              )
                            : Align(
                                key: const ValueKey('docked-rail'),
                                alignment: Alignment.centerLeft,
                                child: CompactSidebarRail(
                                  onExpand: () =>
                                      setState(() => _sidebarOpen = true),
                                  onNewChat: _newChat,
                                  onSettings: _openSettings,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ColoredBox(
                    color: KrithaColors.bgBase,
                    child: _content(viewport),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
