import 'package:hugeicons/hugeicons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme.dart';
import '../../../widgets/create_popup.dart';
import '../catalogue/catalogue_filter.dart';
import 'catalogue_widgets.dart';

Future<List<CatalogueFilter>?> showCatalogueFiltersDialog(
  BuildContext context, {
  required List<CatalogueFilter> selected,
}) {
  return createPopup<List<CatalogueFilter>>(
    context: context,
    maxWidth: 460,
    builder: (_) => _CatalogueFiltersDialog(selected: selected),
  );
}

class _CatalogueFiltersDialog extends StatefulWidget {
  const _CatalogueFiltersDialog({required this.selected});

  final List<CatalogueFilter> selected;

  @override
  State<_CatalogueFiltersDialog> createState() =>
      _CatalogueFiltersDialogState();
}

class _CatalogueFiltersDialogState extends State<_CatalogueFiltersDialog> {
  late final List<CatalogueFilter> _selected = [...widget.selected];
  late final List<CatalogueFilter> _custom = [
    for (final filter in widget.selected)
      if (!filter.preset) filter,
  ];
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isSelected(CatalogueFilter filter) => _selected.contains(filter);

  void _toggle(CatalogueFilter filter) {
    setState(() {
      if (!_selected.remove(filter)) _selected.add(filter);
    });
  }

  void _removeCustom(CatalogueFilter filter) {
    setState(() {
      _custom.remove(filter);
      _selected.remove(filter);
    });
  }

  void _addCustom() {
    final input = _controller.text.trim();
    if (input.isEmpty || input.contains('=')) {
      setState(() => _error = 'Enter a single filter keyword.');
      return;
    }
    final filter = CatalogueFilter(value: input).normalized();
    if (!filter.isValid) {
      setState(() => _error = 'Enter a single filter keyword.');
      return;
    }
    setState(() {
      _custom.removeWhere((item) => item.value == filter.value);
      _custom.add(filter);
      if (!_selected.contains(filter)) _selected.add(filter);
      _controller.clear();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CreatePopup(
      title: 'Filters',
      subtitle: 'Choose the Hub filters used for this catalogue.',
      leading: KrithaIcon(
        icon: HugeIcons.strokeRoundedFilter,
        size: KrithaIcons.md,
        color: KrithaColors.textMuted,
      ),
      actions: [
        PopupSecondaryButton(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        PopupPrimaryButton(
          label: 'Apply',
          onPressed: () =>
              Navigator.of(context)
                  .pop(List<CatalogueFilter>.unmodifiable(_selected)),
        ),
      ],
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          KrithaSpacing.s20,
          0,
          KrithaSpacing.s20,
          KrithaSpacing.s8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Available filters',
              style: TextStyle(
                fontSize: KrithaText.size2xs,
                fontWeight: FontWeight.w600,
                color: KrithaColors.textMuted,
              ),
            ),
            SizedBox(height: KrithaSpacing.s8),
            Wrap(
              spacing: KrithaSpacing.s8,
              runSpacing: KrithaSpacing.s8,
              children: [
                for (final filter in CatalogueFilterPresets.all)
                  CatalogueFilterChip(
                    key: ValueKey('catalogue-preset-${filter.value}'),
                    label: filter.value,
                    selected: _isSelected(filter),
                    onTap: () => _toggle(filter),
                  ),
                for (final filter in _custom)
                  CatalogueFilterChip(
                    key: ValueKey('catalogue-custom-${filter.value}'),
                    label: filter.value,
                    selected: _isSelected(filter),
                    onTap: () => _toggle(filter),
                    onRemove: () => _removeCustom(filter),
                  ),
              ],
            ),
            SizedBox(height: KrithaSpacing.s16),
            Text(
              'Add your own',
              style: TextStyle(
                fontSize: KrithaText.size2xs,
                fontWeight: FontWeight.w600,
                color: KrithaColors.textMuted,
              ),
            ),
            SizedBox(height: KrithaSpacing.s8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('catalogue-filter-input'),
                    controller: _controller,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addCustom(),
                    decoration: KrithaInputs.decoration(
                      hintText: 'Add a filter keyword',
                      dense: true,
                    ),
                  ),
                ),
                SizedBox(width: KrithaSpacing.s8),
                TextButton(
                  key: const ValueKey('catalogue-filter-add'),
                  onPressed: _addCustom,
                  child: const Text('Add'),
                ),
              ],
            ),
            if (_error != null) ...[
              SizedBox(height: KrithaSpacing.s6),
              Text(
                _error!,
                style: TextStyle(
                  fontSize: KrithaText.size2xs,
                  color: KrithaColors.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
