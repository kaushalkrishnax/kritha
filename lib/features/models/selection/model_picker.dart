import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme.dart';
import '../../../data/app_database.dart';
import '../../../widgets/create_popup.dart';
import '../../intelligence/providers/providers.dart';
import '../../providers/providers_controller.dart';
import '../active/active_models.dart';
import '../catalogue/catalogue_model.dart';
import '../widgets/catalogue_widgets.dart';
import '../widgets/workspace_header.dart';
import 'model_display.dart';

Future<ActiveModelAssignment?> showModelPicker(
  BuildContext context, {
  required ModelCapability capability,
}) {
  return createPopup<ActiveModelAssignment>(
    context: context,
    mobileFullScreen: true,
    builder: (_) => _ModelPicker(capability: capability),
  );
}

/// A model that can serve two or more capabilities at once.
class MultimodalChoice {
  const MultimodalChoice({
    required this.modelId,
    required this.displayName,
    required this.capabilities,
  });

  final String modelId;
  final String displayName;
  final Set<ModelCapability> capabilities;

  bool get isMultimodal => capabilities.length >= 2;
}

Future<MultimodalChoice?> showMultimodalModelPicker(
  BuildContext context, {
  required List<MultimodalChoice> choices,
}) {
  return createPopup<MultimodalChoice>(
    context: context,
    mobileFullScreen: true,
    builder: (_) => _MultimodalModelPicker(choices: choices),
  );
}

class _MultimodalModelPicker extends StatelessWidget {
  const _MultimodalModelPicker({required this.choices});

  final List<MultimodalChoice> choices;

  @override
  Widget build(BuildContext context) {
    return CreatePopup(
      title: 'Choose multimodal model',
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          KrithaSpacing.s16,
          KrithaSpacing.s12,
          KrithaSpacing.s16,
          KrithaSpacing.s24,
        ),
        children: [
          for (final choice in choices) _MultimodalChoiceRow(choice: choice),
        ],
      ),
    );
  }
}

class _MultimodalChoiceRow extends StatelessWidget {
  const _MultimodalChoiceRow({required this.choice});

  final MultimodalChoice choice;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(choice),
        borderRadius: BorderRadius.circular(KrithaRadius.base),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: KrithaSpacing.s10,
            vertical: KrithaSpacing.s12,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: KrithaColors.bgTertiary,
                  borderRadius: BorderRadius.circular(KrithaRadius.full),
                ),
                child: KrithaIcon(
                  icon: HugeIcons.strokeRoundedCpu,
                  size: KrithaIcons.base,
                  color: KrithaColors.textMuted,
                ),
              ),
              SizedBox(width: KrithaSpacing.s10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayModelName(choice.displayName),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: KrithaText.sizeSm,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      [
                        for (final capability in choice.capabilities)
                          capability.label,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: KrithaText.size2xs,
                        color: KrithaColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModelPicker extends ConsumerStatefulWidget {
  const _ModelPicker({required this.capability});

  final ModelCapability capability;

  @override
  ConsumerState<_ModelPicker> createState() => _ModelPickerState();
}

class _ModelPickerState extends ConsumerState<_ModelPicker> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activeModelsProvider.notifier).syncProviderModels();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(ActiveModelAssignment item) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    return item.displayName.toLowerCase().contains(query) ||
        item.modelId.toLowerCase().contains(query);
  }

  Widget _section(String title, List<ActiveModelAssignment> models) {
    if (models.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WorkspaceSectionTitle(title),
        for (final model in models) _ModelChoiceRow(model: model),
        SizedBox(height: KrithaSpacing.s14),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeValue = ref.watch(activeModelsProvider).value;
    final recent = (activeValue?.recents ?? const <ActiveModelAssignment>[])
        .where(
          (model) =>
              model.capability == widget.capability && _matches(model),
        )
        .toList();
    final recentKeys = recent.map((item) => item.modelId).toSet();

    final localLitertlm = <ActiveModelAssignment>[];
    final providerModels = <ActiveModelAssignment>[];

    if (activeValue != null) {
      for (final model in activeValue.models.values) {
        final tags = activeValue.tags[model.id];
        if (tags == null) continue;
        final assignment = ActiveModelAssignment.forModel(
          capability: widget.capability,
          model: model,
          tags: tags,
        );
        if (assignment == null) continue;
        if (!_matches(assignment) || recentKeys.contains(assignment.modelId)) {
          continue;
        }
        if (model.providerId == localLitertlmProviderId) {
          localLitertlm.add(assignment);
        } else {
          providerModels.add(assignment);
        }
      }
    }

    return CreatePopup(
      title: 'Choose ${widget.capability.label.toLowerCase()} model',
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              KrithaSpacing.s16,
              KrithaSpacing.s14,
              KrithaSpacing.s16,
              KrithaSpacing.s12,
            ),
            child: Container(
              height: 50,
              padding: EdgeInsets.symmetric(horizontal: KrithaSpacing.s14),
              decoration: BoxDecoration(
                color: KrithaColors.bgPrimary,
                borderRadius: BorderRadius.circular(KrithaRadius.base),
                border: Border.all(color: KrithaColors.borderSubtle),
              ),
              child: Row(
                children: [
                  KrithaIcon(
                    icon: HugeIcons.strokeRoundedSearch01,
                    size: KrithaIcons.base,
                    color: KrithaColors.textMuted,
                  ),
                  SizedBox(width: KrithaSpacing.s10),
                  Expanded(
                    child: TextField(
                      controller: _search,
                      autofocus: true,
                      onChanged: (value) => setState(() => _query = value),
                      decoration: const InputDecoration(
                        hintText:
                            'Search recent, local, and provider models',
                      ),
                    ),
                  ),
                  if (_query.isNotEmpty)
                    IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                      icon: KrithaIcon(
                        icon: HugeIcons.strokeRoundedX,
                        size: KrithaIcons.sm,
                        color: KrithaColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                KrithaSpacing.s16,
                KrithaSpacing.s4,
                KrithaSpacing.s16,
                KrithaSpacing.s24,
              ),
              children: [
                if (activeValue == null)
                  const CatalogueLoading(label: 'Loading available models…'),
                _section('Recent models', recent),
                _section('Local LiteRT-LM', localLitertlm),
                _section('Provider models', providerModels),
                if (recent.isEmpty &&
                    localLitertlm.isEmpty &&
                    providerModels.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: KrithaSpacing.s32,
                      horizontal: KrithaSpacing.s16,
                    ),
                    child: Center(
                      child: Text(
                        'No ${widget.capability.label.toLowerCase()} models available.',
                        style: TextStyle(
                          fontSize: KrithaText.sizeSm,
                          color: KrithaColors.textMuted,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelChoiceRow extends ConsumerWidget {
  const _ModelChoiceRow({required this.model});

  final ActiveModelAssignment model;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayName = displayModelName(model.displayName);
    final active = ref.watch(activeModelsProvider).value;
    final record = active?.models[model.modelId];
    final isLocal = record?.providerId == localLitertlmProviderId;
    final providerConfig = ref
        .watch(providersControllerProvider)
        .value
        ?.configurationFor(record?.providerId ?? '');
    final providerLabel = isLocal
        ? 'Local LiteRT-LM'
        : (providerConfig != null
            ? providerDisplayName(providerConfig.alias)
            : 'Remote provider');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(model),
        borderRadius: BorderRadius.circular(KrithaRadius.base),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: KrithaSpacing.s10,
            vertical: KrithaSpacing.s12,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: KrithaColors.bgTertiary,
                  borderRadius: BorderRadius.circular(KrithaRadius.full),
                ),
                child: KrithaIcon(
                  icon: isLocal
                      ? HugeIcons.strokeRoundedCpu
                      : HugeIcons.strokeRoundedCloud,
                  size: KrithaIcons.base,
                  color: KrithaColors.textMuted,
                ),
              ),
              SizedBox(width: KrithaSpacing.s10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: KrithaText.sizeSm,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      providerLabel,
                      style: TextStyle(
                        fontSize: KrithaText.size2xs,
                        color: KrithaColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
