import 'package:flutter/foundation.dart';

/// Hub query keys used by catalogue filters.
///
/// The Models UI only exposes filter values (keywords); the key stays an
/// implementation detail so requests remain valid Hub queries.
abstract final class CatalogueFilterKeys {
  static const tag = 'filter';
}

/// One filter sent to the Hub model listing endpoint.
@immutable
class CatalogueFilter {
  const CatalogueFilter({
    required this.value,
    this.key = CatalogueFilterKeys.tag,
    this.preset = false,
  });

  final String key;
  final String value;

  /// Presets are offered by the app and cannot be deleted, only toggled.
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

/// Filters the Models page offers out of the box.
abstract final class CatalogueFilterPresets {
  static const litertLmValue = 'litert-lm';

  /// The Hub lists LiteRT-LM repositories under this tag, so a tag filter works
  /// for both the initial listing and search results.
  static const litertLm = CatalogueFilter(
    key: CatalogueFilterKeys.tag,
    value: litertLmValue,
    preset: true,
  );

  static const all = <CatalogueFilter>[litertLm];

  /// Applied on first load so the catalogue only lists runnable LiteRT-LM
  /// repositories.
  static const defaults = <CatalogueFilter>[litertLm];
}
