import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../widgets/back_navigation.dart';
import '../intelligence/runtime_ids.dart';
import '../providers/providers_controller.dart';
import 'providers.dart';
import 'selection/model_display.dart';
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
                  onBack: () => goBackOrExit(context),
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
            ),
            SizedBox(height: KrithaSpacing.s12),
          ],
        ],
      ),
    );
  }
}

class _CapabilitySlot extends ConsumerWidget {
  const _CapabilitySlot({
    required this.capability,
    required this.state,
    required this.onChoose,
    required this.onDeactivate,
  });

  final ModelCapability capability;
  final ActiveModelsState state;
  final VoidCallback onChoose;
  final VoidCallback onDeactivate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = state.statusFor(capability);
    final assignment = state.assignments[capability];
    final remote = assignment != null && assignment.sourceId != localProviderId;
    final provider = remote
        ? ref
              .watch(providersControllerProvider)
              .value
              ?.configurationFor(assignment.sourceId)
        : null;
    final providerConfigured = provider?.configured ?? false;
    final providerAlias = provider?.alias ?? assignment?.sourceId;
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
                  color:
                      status == ActiveAssignmentStatus.active ||
                          providerConfigured
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
              _StatusChip(
                status: status,
                providerConfigured: providerConfigured,
              ),
            ],
          ),
          SizedBox(height: KrithaSpacing.s12),
          Text.rich(
            _message(status, assignment, providerAlias),
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
            children: _actions(assignment),
          ),
        ],
      ),
    );
  }

  InlineSpan _message(
    ActiveAssignmentStatus status,
    ActiveModelAssignment? assignment,
    String? providerAlias,
  ) {
    if (status == ActiveAssignmentStatus.assigned) {
      final modelName = displayModelName(assignment!.displayName);
      final providerName = displayPublisherName(
        providerAlias ?? assignment.sourceId,
      );
      return TextSpan(
        children: [
          _strong(modelName),
          const TextSpan(text: ' is assigned through '),
          _strong(providerName),
          const TextSpan(text: '.'),
        ],
      );
    }
    if (status == ActiveAssignmentStatus.active) {
      return TextSpan(
        text:
            'Assigned to ${displayModelName(assignment!.displayName)} through '
            '${assignment.runtimeId}. Runtime compatibility is checked on use, '
            'and the engine loads only on demand.',
      );
    }
    if (status == ActiveAssignmentStatus.ready) {
      final name = displayModelName(
        state.configuredModel?.displayName ??
            state.configurationFileName ??
            'the validated local model',
      );
      return TextSpan(
        text:
            '$name is validated. Until you assign a text model, chat uses it '
            'as the legacy local text model.',
      );
    }
    if (status == ActiveAssignmentStatus.stale) {
      final name = displayModelName(
        assignment?.displayName ?? 'the previous model',
      );
      return TextSpan(
        text: 'Previously assigned to $name, but it is no longer available.',
      );
    }
    final message = state.configurationMessage;
    return TextSpan(
      text:
          message ??
          'Choose a model from local inventory or a connected provider.',
    );
  }

  TextSpan _strong(String value) {
    return TextSpan(
      text: value,
      style: const TextStyle(fontWeight: FontWeight.w700),
    );
  }

  List<Widget> _actions(ActiveModelAssignment? assignment) {
    return [
      WorkspaceOutlinedAction(label: 'Choose model', onPressed: onChoose),
      if (assignment != null)
        WorkspaceOutlinedAction(
          label: 'Remove assignment',
          onPressed: onDeactivate,
        ),
    ];
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.providerConfigured});

  final ActiveAssignmentStatus status;
  final bool providerConfigured;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ActiveAssignmentStatus.active => ('Assigned', KrithaColors.success),
      ActiveAssignmentStatus.assigned when providerConfigured => (
        'Configured',
        KrithaColors.success,
      ),
      ActiveAssignmentStatus.assigned => ('Needs setup', KrithaColors.warning),
      ActiveAssignmentStatus.ready => (
        'Local model ready',
        KrithaColors.accentLightBlue,
      ),
      ActiveAssignmentStatus.stale => ('Attention', KrithaColors.warning),
      ActiveAssignmentStatus.noModel => (
        'Not assigned',
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
