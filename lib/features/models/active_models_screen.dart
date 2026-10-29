import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import 'providers.dart';
import 'selection/model_picker.dart';
import 'widgets/catalogue_widgets.dart';
import 'widgets/workspace_header.dart';

class ActiveModelsScreen extends ConsumerWidget {
  const ActiveModelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    watchKrithaPalette(context);
    final active = ref.watch(activeModelsProvider);

    return Scaffold(
      backgroundColor: KrithaColors.bgBase,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: [
                WorkspaceHeader(
                  title: 'Active models',
                  onBack: () => context.go('/models'),
                ),
                Expanded(
                  child: active.when(
                    data: (state) => _ActiveBody(state: state),
                    loading: () => const CatalogueLoading(
                      label: 'Loading active assignments…',
                    ),
                    error: (error, stackTrace) => Padding(
                      padding: EdgeInsets.all(KrithaSpacing.s16),
                      child: CatalogueErrorView(
                        failure: const CatalogueFailure(
                          kind: CatalogueFailureKind.unknown,
                          message: 'Active assignments could not be loaded from local storage.',
                        ),
                        onRetry: () => ref.invalidate(activeModelsProvider),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveBody extends ConsumerWidget {
  const _ActiveBody({required this.state});

  final ActiveModelsState state;

  Future<void> _choose(
    BuildContext context,
    WidgetRef ref,
    ModelCapability capability,
  ) async {
    try {
      final selected = await showModelPicker(context, capability: capability);
      if (selected == null || !context.mounted) return;
      await ref
          .read(activeModelsProvider.notifier)
          .assignModel(
            capability: capability,
            sourceId: selected.sourceId,
            modelId: selected.modelId,
            displayName: selected.displayName,
            runtimeId: selected.runtimeId,
          );
    } on ActiveModelException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The assignment could not be saved.')),
      );
    }
  }

  Future<void> _deactivate(
    BuildContext context,
    WidgetRef ref,
    ModelCapability capability,
  ) async {
    try {
      await ref.read(activeModelsProvider.notifier).deactivate(capability);
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The assignment could not be removed.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        KrithaSpacing.s16,
        KrithaSpacing.s4,
        KrithaSpacing.s16,
        KrithaSpacing.s32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final capability in ModelCapability.discoverable) ...[
            _CapabilitySlot(
              capability: capability,
              state: state,
              onChoose: () => _choose(context, ref, capability),
              onDeactivate: () => _deactivate(context, ref, capability),
              onExploreModels: () => context.go('/models'),
            ),
            SizedBox(height: KrithaSpacing.s12),
          ],
        ],
      ),
    );
  }
}

class _CapabilitySlot extends StatelessWidget {
  const _CapabilitySlot({
    required this.capability,
    required this.state,
    required this.onChoose,
    required this.onDeactivate,
    required this.onExploreModels,
  });

  final ModelCapability capability;
  final ActiveModelsState state;
  final VoidCallback onChoose;
  final VoidCallback onDeactivate;
  final VoidCallback onExploreModels;

  @override
  Widget build(BuildContext context) {
    final status = state.statusFor(capability);
    final assignment = state.assignments[capability];
    return WorkspaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: KrithaColors.bgTertiary,
                  borderRadius: BorderRadius.circular(KrithaRadius.base),
                  border: Border.all(color: KrithaColors.borderSubtle),
                ),
                child: KrithaIcon(
                  icon: capabilityIcon(capability),
                  size: KrithaIcons.base,
                  color: status == ActiveAssignmentStatus.active
                      ? KrithaColors.success
                      : KrithaColors.textMuted,
                ),
              ),
              SizedBox(width: KrithaSpacing.s10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      capability.label,
                      style: TextStyle(
                        fontSize: KrithaText.sizeMd,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      capability.description,
                      style: TextStyle(
                        fontSize: KrithaText.sizeXs,
                        color: KrithaColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: KrithaSpacing.s8),
              _StatusChip(status: status),
            ],
          ),
          SizedBox(height: KrithaSpacing.s12),
          Text(
            _message(status, assignment, capability),
            style: TextStyle(
              fontSize: KrithaText.sizeXs,
              color: status == ActiveAssignmentStatus.stale
                  ? KrithaColors.warning
                  : KrithaColors.textMuted,
              height: 1.45,
            ),
          ),
          SizedBox(height: KrithaSpacing.s12),
          Wrap(
            spacing: KrithaSpacing.s8,
            runSpacing: KrithaSpacing.s8,
            children: _actions(status, assignment, capability),
          ),
        ],
      ),
    );
  }

  String _message(
    ActiveAssignmentStatus status,
    ActiveModelAssignment? assignment,
    ModelCapability capability,
  ) {
    if (status == ActiveAssignmentStatus.noRuntime) {
      return 'No execution path for ${capability.label.toLowerCase()} is '
          'available in this build.';
    }
    if (status == ActiveAssignmentStatus.assigned) {
      return '${assignment!.displayName} is saved from ${assignment.sourceId}. '
          'Provider chat routing is not available yet.';
    }
    if (status == ActiveAssignmentStatus.active) {
      return 'Assigned to ${assignment!.displayName} through '
          '${assignment.runtimeId}. Runtime compatibility is checked on use, '
          'and the engine loads only on demand.';
    }
    if (status == ActiveAssignmentStatus.ready) {
      final name =
          state.configuredModel?.displayName ??
          state.configurationFileName ??
          'the validated local model';
      return '$name is validated and ready to assign.';
    }
    if (status == ActiveAssignmentStatus.stale) {
      final name = assignment?.displayName ?? 'the previous model';
      return 'Previously assigned to $name, but it is no longer available.';
    }
    final message = state.configurationMessage;
    return message ??
        'Choose a model from the available local or configured provider sources.';
  }

  List<Widget> _actions(
    ActiveAssignmentStatus status,
    ActiveModelAssignment? assignment,
    ModelCapability capability,
  ) {
    if (status == ActiveAssignmentStatus.noRuntime) {
      if (assignment == null) {
        return const [_DisabledAction(label: 'No execution path')];
      }
      return const [_DisabledAction(label: 'No execution path')];
    }
    if (status == ActiveAssignmentStatus.active ||
        status == ActiveAssignmentStatus.assigned) {
      return [
        WorkspaceOutlinedAction(label: 'Choose model', onPressed: onChoose),
        WorkspaceOutlinedAction(
          label: 'Remove assignment',
          onPressed: onDeactivate,
        ),
      ];
    }
    if (status == ActiveAssignmentStatus.stale ||
        status == ActiveAssignmentStatus.ready ||
        status == ActiveAssignmentStatus.noModel) {
      return [
        WorkspaceOutlinedAction(label: 'Choose model', onPressed: onChoose),
        if (assignment != null)
          WorkspaceOutlinedAction(
            label: 'Remove assignment',
            onPressed: onDeactivate,
          ),
      ];
    }
    return [
      WorkspaceOutlinedAction(
        label: 'Explore local models',
        onPressed: onExploreModels,
      ),
    ];
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ActiveAssignmentStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ActiveAssignmentStatus.active => ('Assigned', KrithaColors.success),
      ActiveAssignmentStatus.assigned => ('Assigned', KrithaColors.warning),
      ActiveAssignmentStatus.ready => (
        'File validated',
        KrithaColors.accentLightBlue,
      ),
      ActiveAssignmentStatus.stale => ('Attention', KrithaColors.warning),
      ActiveAssignmentStatus.noModel => ('No model', KrithaColors.textMuted),
      ActiveAssignmentStatus.noRuntime => (
        'Unavailable',
        KrithaColors.textMuted,
      ),
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: KrithaSpacing.s8,
        vertical: KrithaSpacing.s4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(KrithaRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: KrithaText.size2xs,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _DisabledAction extends StatelessWidget {
  const _DisabledAction({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: null,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KrithaRadius.base),
        ),
      ),
      child: Text(label),
    );
  }
}
