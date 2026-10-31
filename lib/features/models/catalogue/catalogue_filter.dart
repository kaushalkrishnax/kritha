import 'package:flutter/foundation.dart';

/// Hub query keys used by catalogue filters.
abstract final class CatalogueFilterKeys {
  static const tag = 'filter';
}

/// Filter sent to Hub model listing endpoint.
@immutable
class CatalogueFilter {
  const CatalogueFilter({
    required this.value,
    this.key = CatalogueFilterKeys.tag,
    this.preset = false,
  });

  final String key;
  final String value;

  /// Presets are built-in and can only be toggled.
  final bool preset;

  String get id => '$key=$value';

  bool get isValid => value.trim().isNotEmpty;

  CatalogueFilter normalized() =>
      CatalogueFilter(key: key, value: value.trim(), preset: preset);

  @override
  bool operator ==(Object other) =>
      other is CatalogueFilter && other.key == key && other.value == value;

  @override
  int get hashCode => Object.hash(key, value);

  @override
  String toString() => value;
}

/// Built-in catalogue filters.
abstract final class CatalogueFilterPresets {
  static const litertLmValue = 'litert-lm';

  /// LiteRT-LM tag filter for initial listing and search results.
  static const litertLm = CatalogueFilter(
    key: CatalogueFilterKeys.tag,
    value: litertLmValue,
    preset: true,
  );

  static const all = <CatalogueFilter>[litertLm];

  /// Default initial filter to list runnable LiteRT-LM repositories.
  static const defaults = <CatalogueFilter>[litertLm];
}
