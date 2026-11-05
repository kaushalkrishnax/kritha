import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/theme.dart';
import '../../data/app_database.dart';
import '../intelligence/providers/providers.dart';
import '../providers/providers_controller.dart';
import 'providers.dart';
import 'selection/model_display.dart';
import 'selection/model_picker.dart';
import 'widgets/catalogue_widgets.dart';
import 'widgets/workspace_header.dart';

class ActiveModelsContent extends ConsumerWidget {
  const ActiveModelsContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeModelsProvider);

    return active.when(
      data: (state) => _ActiveBody(state: state),
      loading: () =>
          const CatalogueLoading(label: 'Loading active assignments…'),
      error: (error, stackTrace) => Padding(
        padding: EdgeInsets.all(KrithaSpacing.s16),
        child: CatalogueErrorView(
          failure: const CatalogueFailure(
            kind: CatalogueFailureKind.unknown,
            message:
                'Active assignments could not be loaded from local storage.',
          ),
          onRetry: () => ref.invalidate(activeModelsProvider),
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
            modelId: selected.modelId,
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

  Future<void> _chooseMultimodal(BuildContext context, WidgetRef ref) async {
    final choices = _multimodalChoices(state);
    if (choices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No model with two or more executable capabilities is available.',
          ),
        ),
      );
      return;
    }
    final choice = await showMultimodalModelPicker(context, choices: choices);
    if (choice == null || !context.mounted) return;
    try {
      await ref
          .read(activeModelsProvider.notifier)
          .assignModel(
            capability: choice.capabilities.first,
            modelId: choice.modelId,
            enabledCapabilities: choice.capabilities,
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

  Future<void> _clearMultimodal(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(activeModelsProvider.notifier).clearMultiModel();
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The assignment could not be removed.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final multiCapabilities =
        state.multiModel?.enabledCapabilities ?? const <ModelCapability>{};
    final singleCapabilities = [
      for (final capability in ModelCapability.discoverable)
        if (!multiCapabilities.contains(capability)) capability,
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        KrithaSpacing.s16,
        KrithaSpacing.s4,
        KrithaSpacing.s16,
        KrithaSpacing.s32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WorkspaceSectionTitle('Multimodal'),
          _MultiModelCard(
            state: state,
            onChoose: () => _chooseMultimodal(context, ref),
            onClear: () => _clearMultimodal(context, ref),
          ),
          SizedBox(height: KrithaSpacing.s24),
          WorkspaceSectionTitle('Single Models'),
          if (singleCapabilities.isEmpty)
            WorkspaceCard(
              child: Text(
                'Every capability is covered by the multimodal model.',
                style: TextStyle(
                  fontSize: KrithaText.sizeXs,
                  color: KrithaColors.textMuted,
                ),
              ),
            )
          else
            for (final capability in singleCapabilities) ...[
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

List<MultimodalChoice> _multimodalChoices(ActiveModelsState state) {
  final choices = <MultimodalChoice>[];
  for (final model in state.models.values) {
    final tags = state.tags[model.id];
    final capabilities = {
      for (final capability in ModelCapability.discoverable)
        if (modelSupportsCapability(model, tags, capability)) capability,
    };
    if (capabilities.length < 2) continue;
    choices.add(
      MultimodalChoice(
        modelId: model.id,
        displayName: model.displayName,
        capabilities: Set.unmodifiable(capabilities),
      ),
    );
  }
  return choices;
}

class _MultiModelCard extends ConsumerWidget {
  const _MultiModelCard({
    required this.state,
    required this.onChoose,
    required this.onClear,
  });

  final ActiveModelsState state;
  final VoidCallback onChoose;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final multi = state.multiModel;
    final model = multi == null ? null : state.models[multi.modelId];
    if (multi == null || model == null) {
      return WorkspaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No multimodal model assigned',
              style: TextStyle(
                fontSize: KrithaText.sizeMd,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Route two or more capabilities through one model.',
              style: TextStyle(
                fontSize: KrithaText.sizeXs,
                color: KrithaColors.textMuted,
              ),
            ),
            SizedBox(height: KrithaSpacing.s12),
            WorkspaceOutlinedAction(
              label: 'Choose multimodal model',
              onPressed: onChoose,
            ),
          ],
        ),
      );
    }

    final capability = multi.enabledCapabilities.first;
    final assignment = state.assignments[capability];
    final status = assignment == null
        ? ActiveAssignmentStatus.stale
        : ActiveAssignmentStatus.active;

    final isLocal = model.providerId == localLitertlmProviderId;
    final providerConfig = ref
        .watch(providersControllerProvider)
        .value
        ?.configurationFor(model.providerId);
    final providerLabel = isLocal
        ? 'Local LiteRT-LM'
        : (providerConfig != null
            ? providerDisplayName(providerConfig.alias)
            : 'Remote provider');

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
                  icon: isLocal
                      ? HugeIcons.strokeRoundedAiChip
                      : HugeIcons.strokeRoundedCloud,
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
                      displayModelName(model.displayName),
                      style: TextStyle(
                        fontSize: KrithaText.sizeMd,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      providerLabel,
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
                providerConfigured: true,
              ),
            ],
          ),
          SizedBox(height: KrithaSpacing.s12),
          Wrap(
            spacing: KrithaSpacing.s8,
            runSpacing: KrithaSpacing.s8,
            children: [
              for (final capability in multi.enabledCapabilities)
                CapabilityChip(label: capability.label, selected: true),
            ],
          ),
          SizedBox(height: KrithaSpacing.s12),
          Wrap(
            spacing: KrithaSpacing.s8,
            runSpacing: KrithaSpacing.s8,
            children: [
              WorkspaceOutlinedAction(
                label: 'Change model',
                onPressed: onChoose,
              ),
              WorkspaceOutlinedAction(
                label: 'Remove multimodal',
                onPressed: onClear,
              ),
            ],
          ),
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

  static const _inlineStatusMinWidth = 300.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = state.statusFor(capability);
    final assignment = state.assignments[capability];
    final icon = Container(
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
    );
    final details = Column(
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
    );
    final statusChip = _StatusChip(
      status: status,
      providerConfigured: true,
    );
    return WorkspaceCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stackStatus = constraints.maxWidth < _inlineStatusMinWidth;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  icon,
                  SizedBox(width: KrithaSpacing.s10),
                  Expanded(child: details),
                  if (!stackStatus) ...[
                    SizedBox(width: KrithaSpacing.s8),
                    statusChip,
                  ],
                ],
              ),
              if (stackStatus) ...[
                SizedBox(height: KrithaSpacing.s8),
                statusChip,
              ],
              SizedBox(height: KrithaSpacing.s12),
              Text.rich(
                _message(status, assignment),
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
          );
        },
      ),
    );
  }

  InlineSpan _message(
    ActiveAssignmentStatus status,
    ActiveModelAssignment? assignment,
  ) {
    if (status == ActiveAssignmentStatus.active) {
      return TextSpan(
        text: 'Assigned to ${displayModelName(assignment!.displayName)}.',
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
    return const TextSpan(
      text: 'Choose a downloaded local model or a connected provider.',
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
